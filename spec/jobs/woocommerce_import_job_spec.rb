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
end
