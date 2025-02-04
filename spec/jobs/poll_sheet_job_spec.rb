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
end
