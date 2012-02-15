require 'ar_query'

class AdminAssistant
  class Index
    def initialize(admin_assistant, action_view, current_user, url_params = {}, session = nil)
      @admin_assistant = admin_assistant
      @url_params = url_params
      @action_view = action_view
      @current_user = current_user
      @session = session
    end
    
    def belongs_to_sort_column( ignore_sort = false )
      columns.select { |column|
        column.is_a?(BelongsToColumn) && ( ignore_sort || column.name.to_s == @url_params[:sort])
      }
    end
    def has_one_sort_column( ignore_sort = false )
      columns.select { |column|
        column.is_a?(HasOneColumn) && ( ignore_sort || column.name.to_s == @url_params[:sort])
      }
    end
    def has_many_sort_column( ignore_sort = false )
      columns.select { |column|
        column.is_a?(HasManyColumn) && ( ignore_sort || column.name.to_s == @url_params[:sort])
      }
    end
    
    def columns
      column_names = settings.column_names || model_class.columns.map { |c|
        @admin_assistant.column_name_or_assoc_name(c.name)
      }
      @admin_assistant.columns column_names
    end
    
    def header
      if block = settings.header
        block.call @action_view.params
      else
        @admin_assistant.model_class_name.pluralize.capitalize
      end
    end
    
    def conditions
      settings.conditions
    end
    
    def controller
      @action_view.controller
    end
    
    def find_include
      includes = Array(settings.includes) || []
      belongs_to_sort_column(true).each do |by_assoc|
        includes << by_assoc.name
      end
      has_one_sort_column(true).each do |by_assoc|
        includes << by_assoc.name
      end
      has_many_sort_column(true).each do |by_assoc|
        includes << by_assoc.name
      end
      includes
    end
    
    def model_class
      @admin_assistant.model_class
    end
    
    def order_sql
      if (sc = sort_column)
        first_part = ""
        
        if belongs_to_sort_column && !belongs_to_sort_column.empty?
          first_part = belongs_to_sort_column.first.order_sql_field
        else
          first_part = sc.name
        end
        
        "#{first_part} #{sort_order}"
      else
        settings.sort_by
      end
    end
    
    def per_page
      settings.per_page
    end
    
    def search_autocomplete_url
      settings.search_autocomplete_url
    end
    
    def records
      unless @records
        opts = {}
        
        results = model_class.order(order_sql).scoped( :include => find_include)

        if @url_params[:search]
          ar_query = ARQuery.new
          search.add_to_query(ar_query) 
          results = results.where(ar_query[:conditions])
        end
        
        if conditions
          conditions_sql = conditions.call @url_params, @current_user, @session
          results = results.where(conditions_sql)
        end
        
        opts = { :page => @url_params[:page], :per_page => per_page }
        opts.merge! :total_entries => settings.total_entries if settings.total_entries
        
        @records = results.paginate opts
      end
      
      @records
    end
    
    def render_filter
      slug = "_filter.html.erb"
      abs_template_file = File.join( Rails.root, 'app/views', controller.controller_path, slug )
      if File.exist?(abs_template_file)
        template = abs_template_file
        @action_view.render :file => template
      end
    end
    
    def search
      @search ||= Search.new(@admin_assistant, @url_params['search'])
    end
    
    def search_terms
      @url_params['search']
    end
    
    def settings
      @admin_assistant.index_settings
    end
    
    def sort
      @url_params[:sort]
    end
    
    def sort_column
      if @url_params[:sort]
        columns.detect { |c|
          c.name.to_s == @url_params[:sort]
        } || belongs_to_sort_column
      end
    end
    
    def sort_order
      @url_params[:sort_order] || 'asc'
    end
    
    def view(action_view)
      @view ||= View.new(self, action_view, @admin_assistant)
    end
    
    class Search
      def initialize(admin_assistant, search_params)
        @admin_assistant, @search_params = admin_assistant, search_params
        @search_params ||= {}
      end
      
      def [](name)
        @search_params[name]
      end
    
      def add_to_query(ar_query)
        columns.each do |column|
          column.add_to_query ar_query, "or"
        end
      end
      
      def columns
        search_field_names = settings.search_fields
        if search_field_names.empty?
          [DefaultSearchColumn.new(
            default_terms, @admin_assistant.model_class
          )]
        else
          columns = search_field_names.map { |column_name|
            @admin_assistant.column column_name.to_s
          }
          
          columns.each do |c|
            c.search_terms = default_terms
          end
          columns
        end
      end
      
      def column_views(action_view)
        columns.map { |c|
          opts = {:search => self}
          if c.respond_to?(:name)
            opts[:boolean_labels] = settings.boolean_labels[c.name]
          end
          c.view(action_view, opts)
        }
      end
      
      def default_terms
        @search_params if @search_params.is_a?(String)
      end
      
      def id
      end
      
      def method_missing(meth, *args)
        if column = columns.detect { |c| c.name == meth.to_s }
          column.search_value
        else
          super
        end
      end
    
      def settings
        @admin_assistant.index_settings
      end
    end
    
    class View
      def initialize(index, action_view, admin_assistant)
        @index, @action_view, @admin_assistant =
            index, action_view, admin_assistant
      end
      
      def columns
        @index.columns.map { |c|
          c.view(
            @action_view,
            :boolean_labels => @index.settings.boolean_labels[c.name],
            :sort_order => (@index.sort_order if c.name == @index.sort),
            :link_to_args => @index.settings.link_to_args[c.name.to_sym],
            :acts_as_list_position_column => (@index.settings.acts_as_list_position_column == c.name.to_sym)
          )
        }
      end
      
      def destroy?
        @destroy ||= @admin_assistant.destroy?
      end
      
      def edit?
        @edit ||= (@admin_assistant.edit? || @admin_assistant.controller_actions.include?(:edit))
      end
      
      def right_column?
        edit? or destroy? or show? or @right_column_links or !right_column_lambdas.empty?
      end
      
      def right_column_lambdas
        @admin_assistant.index_settings.right_column_lambdas
      end
      
      def right_column_links(record)
        link_syms = @admin_assistant.index_settings.right_column_links
        
        links = ""
        if edit? && (link_syms.empty? || link_syms.include?(:edit))
          links << @action_view.link_to(
            'Edit', :action => 'edit', :id => record.id
          ) << " "
        end
        if destroy? && (link_syms.empty? || link_syms.include?(:destroy))
          links << @action_view.link_to(
            'Delete', :action => 'destroy', :id => record.id
          ) << ' '
        end
        if show? && (link_syms.empty? || link_syms.include?(:show))
          links << @action_view.link_to(
            'Show', :action => 'show', :id => record.id
          ) << ' '
        end
        right_column_lambdas.each do |lambda|
          link_args = lambda.call record
          links << @action_view.link_to(*link_args)
        end
        if @action_view.respond_to?(:extra_right_column_links_for_index)
          links << (@action_view.extra_right_column_links_for_index(
            record
          ) || '')
        end
        links
      end
      
      def show?
        @show ||= @admin_assistant.show?
      end
      
    end
  end
end
