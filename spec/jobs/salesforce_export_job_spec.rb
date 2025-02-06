require "rails_helper"

RSpec.describe SalesforceImportJob, type: :job do
  it "queues the job" do
    expect {
      SalesforceImportJob.perform_later
    }.to have_enqueued_job
  end

  it "executes perform" do
    LightspeedStubHelpers.stub_lightspeed_account_request
    expect_any_instance_of(SFImport).to receive(:poll_jobs)
    SalesforceImportJob.perform_now
  end
end
