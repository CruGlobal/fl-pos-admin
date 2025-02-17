require "rails_helper"

RSpec.describe WoocommerceImportJob, type: :job do
  it "queues the job" do
    expect {
      WoocommerceImportJob.perform_later
    }.to have_enqueued_job
  end

  it "executes perform" do
    expect_any_instance_of(WooImport).to receive(:poll_jobs)
    WoocommerceImportJob.perform_now
  end

  it "rescues and re-raises exceptions" do
    job = create(:job, type: "WOO_IMPORT", status: :processing)
    LightspeedStubHelpers.stub_lightspeed_account_request
    allow_any_instance_of(WooImport).to receive(:poll_jobs).and_raise("An error occurred")
    expect {
      WoocommerceImportJob.perform_now
    }.to raise_error("An error occurred")
    expect(job.reload.status).to eq("error")
  end
end
