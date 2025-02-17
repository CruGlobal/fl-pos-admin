require "rails_helper"

RSpec.describe LightspeedExtractJob, type: :job do
  it "queues the job" do
    expect {
      LightspeedExtractJob.perform_later
    }.to have_enqueued_job
  end

  it "executes perform" do
    LightspeedStubHelpers.stub_lightspeed_account_request
    expect_any_instance_of(LSExtract).to receive(:poll_jobs)
    LightspeedExtractJob.perform_now
  end

  it "rescues and re-raises exceptions" do
    job = create(:job, type: "LS_EXTRACT", status: :processing)
    LightspeedStubHelpers.stub_lightspeed_account_request
    allow_any_instance_of(LSExtract).to receive(:poll_jobs).and_raise("An error occurred")
    expect {
      LightspeedExtractJob.perform_now
    }.to raise_error("An error occurred")
    expect(job.reload.status).to eq("error")
  end
end
