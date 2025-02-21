class JobsController < ApplicationController
  before_action :set_job, except: %i[index new create]
  before_action :set_form_defaults, only: %i[new edit]

  # GET /jobs
  def index
    job_id = params[:job_id]
    type = params[:type]
    status = params[:status]
    start_date = params[:start_date]
    end_date = params[:end_date]

    q = Job.order(updated_at: :desc).includes(:logs)
    if job_id != ""
      q = q.where(id: job_id)
    end
    q = if type != ""
      q.where(type: type)
    else
      q.where.not(type: ["POLL_SHEET", "WOO_REFRESH"])
    end
    if status != ""
      q = q.where(status: status)
    end
    if start_date != ""
      q = q.where("start_date >= ?", start_date)
    end
    if end_date != ""
      q = q.where("end_date <= ?", end_date)
    end
    @jobs = q.paginate(page: params[:page], per_page: 10)
  end

  # GET /jobs/1
  def show
  end

  # GET /jobs/new
  def new
    @job = Job.new
    @event_options = get_event_options
    @job_status = "created"
    @job_type = "LS_EXTRACT"
    @start_date_default = Date.today.last_week(:thursday)
    @end_date_default = @start_date_default + 4.days
  end

  # GET /jobs/1/edit
  def edit
    @job = Job.find(params[:id])
    @job_status = @job.status
    @job_type = @job.type
    @start_date_default = @job.start_date
    @end_date_default = @job.end_date
  end

  # POST /jobs
  def create
    sf_job = SFImport.new.create_job(job_params[:shop_id], job_params[:start_date], job_params[:end_date])
    ls_job = LSExtract.new.create_job(job_params[:shop_id], job_params[:start_date], job_params[:end_date])

    SalesforceImportJob.perform_later
    LightspeedExtractJob.perform_later

    if sf_job.persisted? && ls_job.persisted?
      redirect_to jobs_path, notice: "Job was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # DELETE /jobs/1
  def destroy
    @job.destroy
    redirect_to jobs_url, notice: "Job was successfully destroyed."
  end

  # POST /jobs/1/restart
  def restart
    if @job.restart_job
      redirect_to jobs_path, notice: "Job was successfully restarted."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /jobs/1
  def update
    if @job.update!(job_params)
      redirect_to jobs_path, notice: "Job was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_job
    @job = Job.find(params.expect(:id))
  end

  # Only allow a list of trusted parameters through.
  def job_params
    params.expect(job: [:id, :type, :event_code, :status, :shop_id, :start_date, :end_date])
  end

  def set_form_defaults
    @job = if params[:id]
      Job.find(params[:id])
    else
      Job.new
    end
    @job.start_date = @job.start_date || params[:start_date] || Date.today.last_week(:thursday)
    @job.end_date = @job.end_date || params[:start_date] || @job.start_date + 4.days
    @job_status = @job.status || "created"
    @event_options = get_event_options
    @start_date_default = @job.start_date
    @end_date_default = @job.end_date
  end

  def get_event_options
    shops = LightspeedApiHelper.new.shops
    shops.select! { |shop| !shop.Contact["custom"].start_with?("P-") }
    shops.map { |shop| [shop.name, shop.shopID] }
  end
end
