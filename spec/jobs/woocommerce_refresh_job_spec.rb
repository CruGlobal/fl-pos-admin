require "rails_helper"

RSpec.describe WoocommerceRefreshJob, type: :job do
  it "queues the job" do
    expect {
      WoocommerceRefreshJob.perform_later
    }.to have_enqueued_job
  end

  it "executes perform" do
    expect_any_instance_of(WooRefresh).to receive(:poll_jobs)
    expect { WoocommerceRefreshJob.perform_now }.to change { Job.count }.by(1)
  end
end
