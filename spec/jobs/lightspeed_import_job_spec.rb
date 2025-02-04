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
end
