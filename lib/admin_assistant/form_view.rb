class AdminAssistant
  class FormView
    def initialize(record, admin_assistant, action_view)
      @record, @admin_assistant, @action_view =
          record, admin_assistant, action_view
    end
    
    def action
      if %w(new create).include?(controller.action_name)
        'create'
      else
        'update'
      end
    end
    
    def simple_action_name
      if %w(new create).include?(controller.action_name)
        'new'
      else
        'edit'
      end
    end
    
    def after_column_html(column)
      if after = render_from_custom_template("_after_#{column.name}_input")
        after
      else
        helper_method = "after_#{column.name}_input"
        if @action_view.respond_to?(helper_method)
          @action_view.send(helper_method, @record)
        end
      end
    end
    
    def column_html(column, rails_form)
      hff = render_from_custom_template "_#{column.name}_input"
      hff ||= column_html_from_helper_method(column)
      hff ||= if settings.read_only.include?(column.name)
        column.form_value(@record)
      elsif column.respond_to?(:add_to_form)
        column.add_to_form(rails_form)
      else
        virtual_column_html column
      end
      if ah = after_column_html(column)
        hff << ah
      end
      hff
    end
    
    def column_html_from_helper_method(column)
      html_method = "#{column.name}_html_for_form"
      if @action_view.respond_to?(html_method)
        @action_view.send(html_method, @record)
      end
    end
    
    def column_names
      settings.send("column_names_for_#{simple_action_name}") || settings.column_names ||
          model_class.columns.reject { |ar_column|
            %w(id created_at updated_at).include?(ar_column.name)
          }.map { |ar_column|
            @admin_assistant.column_name_or_assoc_name(ar_column.name)
          }
    end
    
    def columns
      @admin_assistant.columns(column_names).map { |c|
        c.view(@action_view, :input => settings.inputs[c.name.to_sym])
      }
    end
    
    def header
      if block = settings.header
        block.call @action_view.params
      else
        @admin_assistant.model_class_name.pluralize.capitalize
      end
    end
    
    def hide
      settings.hide
    end
    
    def controller
      @action_view.controller
    end
    
    def extra_submit_buttons
      settings.submit_buttons
    end
    
    def form_for_args
      args = { :url => {:action => action, :id => @record.id}, :html => { :id => "aa_form" }}
      args[:html][:method] = "put" if args[:url][:action] == "update"
      unless @admin_assistant.paperclip_attachments.empty? && @admin_assistant.file_columns.empty? && !settings.inputs.any?{ |i| i.last == :file }
        args[:html][:multipart] = true
      end
      args
    end
    
    def model_class
      @admin_assistant.model_class
    end
    
    def render_from_custom_template(slug)
      abs_template_file = File.join(
        Rails.root, 'app/views', controller.controller_path, 
        "#{slug}.html.erb"
      )
      if File.exist?(abs_template_file)
        template = abs_template_file
        @action_view.render(
          :file => template,
          :locals => {model_class.name.underscore.to_sym => @record}
        )
      end
    end
    
    def settings
      @admin_assistant.form_settings
    end
    
    def submit_value
      action.capitalize
    end
    
    def title
      (@record.id ? "Edit" : "New") + " #{@admin_assistant.model_class_name}"
    end
    
    def virtual_column_html(column)
      input_name = "record[#{column.name}]"
      input_type = settings.inputs[column.name.to_sym]
      fv = column.form_value @record
      if input_type
        case input_type
          when :check_box
            @action_view.send(:check_box_tag, input_name, '1', fv) +
                @action_view.send(:hidden_field_tag, input_name, '0')
          when :password
            @action_view.send(:password_field_tag, input_name)
          when :file
            @action_view.send(:file_field_tag, input_name)
        end
      else
        @action_view.send(:text_field_tag, input_name, fv)
      end
    end
  end
end
