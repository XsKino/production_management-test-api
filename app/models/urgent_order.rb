class UrgentOrder < ProductionOrder
  validates :deadline, presence: true
end