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

  it "rescues and re-raises exceptions" do
    job = create(:job, type: "SF_IMPORT", status: :processing)
    LightspeedStubHelpers.stub_lightspeed_account_request
    allow_any_instance_of(SFImport).to receive(:poll_jobs).and_raise("An error occurred")
    expect {
      SalesforceImportJob.perform_now
    }.to raise_error("An error occurred")
    expect(job.reload.status).to eq("error")
  end
end
