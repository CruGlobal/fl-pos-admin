class CleanJobs

  def create_job()
    shop = @lsh.find_shop(shop_id)
    job = Job.create(
      type: "CLEAN_JOBS",
      status: :created
    )
    job.save!
    job
  end

  def log job, message
    log = job.logs.create(content: "[CLEAN_JOBS] #{message}")
    log.save!
    Rails.logger.info log.content
  end

  def poll_jobs
    # if there are any current jobs other than CLEAN_JOBS currently in processing status, wait 5 minutes and try again
    if Job.where.not(type: "CLEAN_JOBS").where(status: :processing).count > 0
      Rails.logger.info "CLEAN_JOBS POLLING: Jobs are currently processing. Waiting 5 minutes before trying again."
      return
    end
    jobs = Job.where(type: "CLEAN_JOBS", status: :created).all
    if jobs.count == 0
      Rails.logger.info "POLLING: No CLEAN_JOBS jobs found."
      return
    end
    # Mark all found jobs as paused
    jobs.each do |job|
      job.status_paused!
      job.save!
    end
    jobs.each do |job|
      Rails.logger.info "POLLING: Found CLEAN_JOBS job #{job.id}. Starting job."
      handle_job job
    end
  end

  def handle_job(job)
    # Process the job
    job.status_processing!
    job.save!
    log job, "Processing job #{job.id}. Cleaning old jobs."
    # Find all jobs older than a month and clean them out.
    count = Job.where("created_at < ?", 1.month.ago).count
    log job, "Found #{count} jobs older than a month. Deleting them."
    ActiveRecord::Base.transaction do
      # INFO: Log deletions are cascaded at a database level
      ActiveRecord::Base.connection.execute("DELETE FROM logs WHERE jobs_id IN (SELECT id FROM jobs WHERE created_at < '#{1.month.ago}')")
      ActiveRecord::Base.connection.execute("DELETE FROM jobs WHERE created_at < '#{1.month.ago}'")
    end
    job.status_complete!
    job.save!
  end

end
