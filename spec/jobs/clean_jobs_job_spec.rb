require "rails_helper"

RSpec.describe CleanJobsJob, type: :job do
  it "queues the job" do
    expect {
      CleanJobsJob.perform_later
    }.to have_enqueued_job
  end

  it "executes perform" do
    expect_any_instance_of(CleanJobs).to receive(:poll_jobs)
    expect { CleanJobsJob.perform_now }.to change { Job.count }.by(1)
  end

  it "rescues and re-raises exceptions" do
    job = create(:job, type: "CLEAN_JOBS", status: :processing)
    LightspeedStubHelpers.stub_lightspeed_account_request
    allow_any_instance_of(CleanJobs).to receive(:poll_jobs).and_raise("An error occurred")
    expect {
      CleanJobsJob.perform_now
    }.to raise_error("An error occurred")
    expect(job.reload.status).to eq("error")
  end
end
