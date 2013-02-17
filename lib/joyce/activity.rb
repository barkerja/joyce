require 'active_record'

module Joyce
  class Activity < ActiveRecord::Base
    self.table_name = 'joyce_activities'

    belongs_to :actor, :polymorphic => true
    belongs_to :obj, :polymorphic => true
    has_and_belongs_to_many :streams, :join_table => "joyce_activities_streams"
    has_many :activity_targets, :dependent => :delete_all

    attr_accessible :actor, :verb, :obj

    validates_presence_of :actor, :verb

    extend Joyce::Scopes
    default_scope order("joyce_activities.created_at DESC")

    # Returns an array of targets for the given name.
    #
    # @return [Array] the targets for the given name.
    def get_targets(name=:target)
      ActivityTarget.where(:name => name, :activity_id => id).map{ |at| at.target }
    end

    # Sets the activity targets.
    #
    # @param [Hash] targets a Hash of type `{ :name => target }`.
    def set_targets(targets)
      raise ArgumentError.new("Parameter for set_targets should be a hash of type {:name => target}") unless targets.is_a?(Hash)

      targets.each do |name, target|
        if target.is_a?(Array)
          target.each do |t|
            ActivityTarget.create(:name => name, :activity => self, :target => t)
          end
        else
          ActivityTarget.create(:name => name, :activity => self, :target => target)
        end
      end
    end

    def verb=(value)
      verb_value = value.nil? ? nil : value.to_s
      write_attribute(:verb, verb_value)
    end

    def verb
      verb_value = read_attribute(:verb)
      verb_value.nil? ? nil : verb_value.constantize
    end

    # Returns subscribers for this activity.
    def subscribers
      subscriptions = Joyce::StreamSubscriber
        .joins("JOIN joyce_activities_streams AS jas ON joyce_streams_subscribers.stream_id = jas.stream_id")
        .includes(:subscriber)
        .where("jas.activity_id = ?", self.id)
        .where("joyce_streams_subscribers.ended_at IS NULL OR joyce_streams_subscribers.ended_at >= ?", self.created_at)
        .where("joyce_streams_subscribers.started_at <= ?", self.created_at)
      subscriptions.collect{ |s| s.subscriber }.uniq
    end
  end
end
