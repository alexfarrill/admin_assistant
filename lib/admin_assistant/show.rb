require 'ar_query'

class AdminAssistant
  class Show
    def initialize(admin_assistant, url_params = {})
      @admin_assistant = admin_assistant
      @url_params = url_params
    end
    
    def title
      "Show" + " #{@admin_assistant.model_class_name}"
    end
    
    def columns
      column_names = settings.column_names || model_class.columns.map { |c|
        @admin_assistant.column_name_or_assoc_name(c.name)
      }
      @admin_assistant.columns column_names
    end
    
    def model_class
      @admin_assistant.model_class
    end
    
    def settings
      @admin_assistant.show_settings
    end
    
    def view(action_view)
      View.new self, action_view
    end
    
    class View
      def initialize(index, action_view)
        @index, @action_view = index, action_view
      end
      
      def columns
        @index.columns.map { |c|
          c.view(
            @action_view,
            :boolean_labels => @index.settings.boolean_labels[c.name],
            :link_to_args => @index.settings.link_to_args[c.name.to_sym],
            :acts_as_list_position_column => (@index.settings.acts_as_list_position_column == c.name.to_sym)
          )
        }
      end
    end
  end
end
