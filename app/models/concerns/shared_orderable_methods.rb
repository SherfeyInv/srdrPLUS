module SharedOrderableMethods
  extend ActiveSupport::Concern

  included do

    # Params:
    #
    # Returns:
    #   nil
    #
    # Determines and adds ordering to the object within the object's scope.
    def set_ordering_scoped_by(object_scope)
      position = self.class.where("#{ object_scope }": self.send(object_scope)).count + 1
      create_ordering(position: position)
    end
  end

  class_methods do
  end
end
