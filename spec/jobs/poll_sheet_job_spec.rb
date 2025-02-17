require "rails_helper"

RSpec.describe PollSheetJob, type: :job do
  it "queues the job" do
    expect {
      PollSheetJob.perform_later
    }.to have_enqueued_job
  end

  it "executes perform" do
    expect_any_instance_of(PollSheet).to receive(:poll_jobs)
    expect { PollSheetJob.perform_now }.to change { Job.count }.by(1)
  end

  it "rescues and re-raises exceptions" do
    job = create(:job, type: "POLL_SHEET", status: :processing)
    LightspeedStubHelpers.stub_lightspeed_account_request
    allow_any_instance_of(PollSheet).to receive(:poll_jobs).and_raise("An error occurred")
    expect {
      PollSheetJob.perform_now
    }.to raise_error("An error occurred")
    expect(job.reload.status).to eq("error")
  end
end
