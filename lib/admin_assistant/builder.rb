class AdminAssistant
  class Builder
    attr_reader :admin_assistant
    
    def initialize(admin_assistant)
      @admin_assistant = admin_assistant
    end
    
    def actions(*a)
      if a.empty?
        @admin_assistant.actions
      else
        @admin_assistant.actions = a
      end
    end
    
    def inputs
      @admin_assistant.form_settings.inputs
    end
    
    def label(column, label)
      @admin_assistant.custom_column_labels[column.to_s] = label
    end
      
    def form
      yield @admin_assistant.form_settings
    end
      
    def index
      yield @admin_assistant.index_settings
    end
    
    def show
      yield @admin_assistant.show_settings
    end
  end
  
  class Settings
    attr_reader :column_names, :column_names_for_new, :column_names_for_edit
    
    def initialize(admin_assistant)
      @admin_assistant = admin_assistant
    end
    
    def columns(*args)
      @column_names = args
    end
    
    def columns_for_new(*args)
      @column_names_for_new = args
    end
    
    def columns_for_edit(*args)
      @column_names_for_edit = args
    end
    
  end
  
  class FormSettings < Settings
    attr_reader :inputs, :submit_buttons
    attr_accessor :header
    
    def hide(&block)
      block ? (@hide = block) : @hide
    end
    
    def initialize(admin_assistant)
      super
      @inputs = {}
      @submit_buttons = []
      @read_only = []
      @header = nil
    end
    
    def header(&block)
      block ? (@header = block) : @header
    end
    
    def read_only(*args)
      if args.empty?
        @read_only
      else
        args.each do |arg| @read_only << arg.to_s; end
      end
    end
  end
  
  class ShowSettings < Settings
    attr_reader :actions, :link_to_args
    attr_accessor :acts_as_list_position_column
    
    def initialize(admin_assistant)
      super
      @actions = {}
      @boolean_labels = {}
      @link_to_args = {}
      @acts_as_list_position_column = nil
    end
    
    def acts_as_list_position_column( value = nil )
      if value
        @acts_as_list_position_column = value
      else
        @acts_as_list_position_column
      end
    end
    
    def boolean_labels(*args)
      if args.size == 1
        args.first.each do |column_name, pairs|
          @boolean_labels[column_name.to_s] = pairs
        end
      else
        @boolean_labels
      end
    end
    
  end
  
  class IndexSettings < Settings
    attr_reader :actions, :link_to_args, :search_fields, :sort_by
    attr_accessor :header, :includes, :total_entries, :remember_params, :right_column_lambdas, :right_column_links, :search_autocomplete_url, :acts_as_list_position_column, :s_actions
    
    def initialize(admin_assistant)
      super
      @actions = {}
      @s_actions = true
      @sort_by = "`#{admin_assistant.model_class.table_name}`.id desc"
      @boolean_labels = {}
      @link_to_args = {}
      @right_column_lambdas = []
      @right_column_links = []
      @per_page = 25
      @search_fields = []
      @remember_params = [:search, :sort, :sort_order, :page, :return_to]
      @acts_as_list_position_column = nil
    end
    
    def search_autocomplete_url( value = nil )
      if value
        @search_autocomplete_url = value
      else
        @search_autocomplete_url
      end
    end
    
    def per_page(*args)
      if args.empty?
        @per_page
      else
        @per_page = args.first
      end
    end
    
    def acts_as_list_position_column( value = nil )
      if value
        @acts_as_list_position_column = value
      else
        @acts_as_list_position_column
      end
    end
    
    def boolean_labels(*args)
      if args.size == 1
        args.first.each do |column_name, pairs|
          @boolean_labels[column_name.to_s] = pairs
        end
      else
        @boolean_labels
      end
    end
    
    def conditions(&block)
      block ? (@conditions = block) : @conditions
    end
    
    def header(&block)
      block ? (@header = block) : @header
    end
    
    def search(*fields)
      @search_fields = fields
    end
    
    def remember(*fields)
      @remember_params = @remember_params + fields
    end
    
    def right_column_lambdas=(*fields)
      @right_column_lambdas = fields
    end
    
    def sort_by(*sb)
      if sb.empty?
        @sort_by
      else
        @sort_by = sb
      end
    end
    
    def show_actions( value )
      @s_actions = value
    end
  end
end
