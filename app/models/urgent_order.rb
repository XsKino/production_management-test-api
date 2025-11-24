class UrgentOrder < ProductionOrder
  validates :deadline, presence: true

  validate :deadline_after_start_date

  private

  # Validate that deadline is not before start_date
  def deadline_after_start_date
    return unless deadline.present? && start_date.present?

    if deadline < start_date
      errors.add(:deadline, "must be greater than or equal to start date")
    end
  end
end
