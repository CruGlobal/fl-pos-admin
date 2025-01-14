class JobsController < ApplicationController
  before_action :set_job, only: %i[ edit update ]
  before_action :set_form_defaults, only: %i[ new edit ]

  # GET /jobs
  def index
    @jobs = Job.order(updated_at: :desc).includes(:logs).paginate(page: params[:page], per_page: 10)
  end

  # GET /jobs/new
  def new
    @job = Job.new
  end

  # GET /jobs/1/edit
  def edit
  end

  # POST /jobs
  def create
    sf_job = SFImport.create_job(job_params[:shop_id], job_params[:start_date], job_params[:end_date])
    ls_job = LSExtract.create_job(job_params[:shop_id], job_params[:start_date], job_params[:end_date])

    SalesforceImportJob.perform_later
    LightspeedExtractJob.perform_later

    if sf_job.persisted? && ls_job.persisted?
      redirect_to jobs_path, notice: "Job was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /jobs/1
  def update
    if @job.update(job_params)
      redirect_to @job, notice: "Job was successfully updated.", status: :see_other
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
    params.fetch(:job => [:shop_id, :start_date, :end_date])
  end

  def set_form_defaults
    @event_options = get_event_options
    @start_date_default = Date.today.last_week(:thursday)
    @end_date_default = @start_date_default + 4.days
  end

  def get_event_options
    shops = LightspeedApiHelper.new.shops
    shops.select! { |shop| !shop.Contact['custom'].start_with?('P-') }
    shops.map { |shop| [shop.name, shop.shopID] }
  end
end
