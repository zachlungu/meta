class UserIdentity < ActiveRecord::Base
  belongs_to :user

  VIEW_WIP_MARKING_WEIGHT = 0.02
  DO_WIP_MARKING_WEIGHT = 1.0
  VIEW_PRODUCT_MARKING_WEIGHT = 0.01

  has_many :markings, as: :markable
  has_many :marks, through: :markings

  def assign_markings_from_wips(my_wips)
    cumulative_vector = []
    my_wips.each do |w|
      cumulative_vector = QueryMarks.new.add_mark_vectors(w.normalized_mark_vector, cumulative_vector)
    end
    QueryMarks.new.update_markings_to_vector_for_object(self, cumulative_vector)
  end

  def assign_markings_from_viewings
    my_views = self.user.viewings
    my_views.each do |v|
      #get mark set of viewable
      if v.weight
        mark_vector = QueryMarks.new.mark_vector_for_object(v.viewable)

        #scale according to significance of product view/ bounty view/ etc
        mark_vector = QueryMarks.new.scale_mark_vector(mark_vector, VIEW_PRODUCT_MARKING_WEIGHT * Math.sqrt(v.weight))

        #add pre-existing mark vector to new mark vector
        old_mark_vector = QueryMarks.new.mark_vector_for_object(self)
        new_mark_vector = QueryMarks.new.add_mark_vectors(old_mark_vector, mark_vector)

        #update identity markings with new mark vector
        QueryMarks.new.update_markings_to_vector_for_object(self, new_mark_vector)
      end
    end
  end

  def assign_markings_from_scratch
    wips_won = self.user.wips_won
    assign_markings_from_wips(wips_won)
    assign_markings_from_viewings
  end

  def get_mark_vector()
    QueryMarks.new.normalized_mark_vector_for_object(self).sort{|a,b| b[1] <=> a[1]}
  end

end