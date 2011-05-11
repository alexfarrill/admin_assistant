require 'admin_assistant/helper'

class AdminAssistant
  module Request
    class Base
      
      include Helper
      
      def initialize(admin_assistant, controller)
        @admin_assistant, @controller = admin_assistant, controller
      end
  
      def action
        @controller.action_name
      end
      
      def format
        @controller.params[:format]
      end
      
      def after_form_html_template
        File.join(
          Rails.root, 'app/views/', @controller.controller_path, 
          '_after_form.html.erb'
        )
      end
      
      def after_index_html_template
        File.join(
          Rails.root, 'app/views/', @controller.controller_path, 
          '_after_index.html.erb'
        )
      end
      
      def after_form_html_template_exists?
        File.exist? after_form_html_template
      end
      
      def after_index_html_template_exists?
        File.exist? after_index_html_template
      end
      
      def model_class
        @admin_assistant.model_class
      end
    
      def params_for_save
        params = {}
        split_params = {}
        whole_params = {}
        @controller.params[:record].each do |k, v|
          k =~ /\([0-9]+i\)$/ ? (split_params[k] = v) : (whole_params[k] = v)
        end
        bases = split_params.map{ |k, v| k.gsub(/\([0-9]+i\)$/, '') }.uniq
        bases.each do |b|
          h = {}
          split_params.each{ |k, v| h[k] = split_params.delete(k) if k =~ /#{b}\([0-9]+i\)$/ }
          from_form_method = "#{b}_from_form".to_sym
          if @controller.respond_to?(from_form_method)
            params[b] = @controller.send(from_form_method, h)
          elsif @record.respond_to?("#{b}=")
            params.merge! h
          end
        end
        whole_params.each do |k, v|  
          from_form_method = "#{k}_from_form".to_sym
          if @controller.respond_to?(from_form_method)
            params[k] = @controller.send(from_form_method, v)
          elsif @record.respond_to?("#{k}=")
            params[k] = v
          end
        end
        params
      end
      
      def redirect_after_create
        url_params = @controller.send( :destination_after_create, @record, @controller.params ) if @controller.respond_to?(:destination_after_create)
        @controller.send :redirect_to, url_params if url_params.is_a?(String)
      end
      
      def redirect_after_update
        url_params = @controller.send( :destination_after_update, @record, @controller.params ) if @controller.respond_to?(:destination_after_update)
        @controller.send :redirect_to, url_params if url_params.is_a?(String)
      end
      
      def redirect_after_save
        if @controller.respond_to?(:destination_after_save)
          url_params = @controller.send( :destination_after_save, @record, @controller.params )
        elsif @controller.params[:return_to]
          url_params = ::ActionController::Routing::Routes.recognize_path( @controller.params[:return_to].gsub(/\?.*$/,''), :method => :get )
        end
        url_params ||= {:action => 'index'}
        
        if url_params.is_a?(String)
          @controller.send :redirect_to, url_params
        else
          @controller.send :redirect_to, url_params.merge(remebered_get_params_without( [:return_to], @controller.params))
        end
      end
      
      def render_after_form
        @controller.send(
          :render_to_string,
          :file => after_form_html_template, :layout => false
        )
      end
      
      def render_after_index
        @controller.send(
          :render_to_string,
          :file => after_index_html_template, :layout => false
        )
      end
      
      def render_form
        html = @controller.send(
          :render_to_string, :file => template_file('form'), :layout => false
        )
        html << render_after_form if after_form_html_template_exists?
        @controller.send :render, :text => html, :layout => true
      end
      
      def render_template_file(template_name = action)
        html = @controller.send(
          :render_to_string, :file => template_file(template_name, format), :layout => false
        )
        html << render_after_index if after_index_html_template_exists?
        @controller.send :render, :text => html, :layout => render_layout?(template_name, format)
      end
      
      def save
        if @controller.respond_to?(:before_save)
          @controller.send(:before_save, @record)
        end
        @record.save
      end
      
      def render_layout?(template_name, format)
        if format == "csv"
          false
        else
          true
        end
      end
    
      def template_file(template_name = action, format = nil)
        if format == "csv"
          "#{File.dirname(__FILE__)}/../views/#{template_name}.csv.erb"
        else
          "#{File.dirname(__FILE__)}/../views/#{template_name}.html.erb"
        end
      end
    end
    
    class Create < Base
      def call
        @record = model_class.new
        @record.attributes = params_for_save
        if save
          redirect_after_create || redirect_after_save
        else
          @controller.instance_variable_set :@record, @record
          render_form
        end
      end
      
      def save
        if @controller.respond_to?(:before_create)
          @controller.send(:before_create, @record)
        end
        result = super
        if @controller.respond_to?(:after_create)
          @controller.send(:after_create, @record)
        end
        result
      end
    end
    
    class Destroy < Base
      def call
        @record = model_class.find @controller.params[:id]
        @record.destroy
        @controller.send :render, :text => ''
      end
    end
    
    class Edit < Base
      def call
        @record = model_class.find @controller.params[:id]
        
        continue = @controller.respond_to?(:before_edit) ? @controller.send(:before_edit, @record ) : true
        if continue
          @controller.instance_variable_set :@record, @record
          render_form
        end
      end
    end
    
    class Index < Base
      def call
        render_template_file
      end
      
      def columns
        @admin_assistant.index_settings.columns
      end
    end
    
    class Show < Base
      def call
        @show = AdminAssistant::Show.new(@admin_assistant, @controller.params)
        @controller.instance_variable_set :@show, @show
        
        @record = model_class.find @controller.params[:id]
        
        continue = @controller.respond_to?(:before_show) ? @controller.send(:before_show, @record ) : true
        if continue
          @controller.instance_variable_set :@record, @record
          render_template_file if @record
        end
      end
      
      def columns
        @admin_assistant.show_settings.columns
      end
    end
    
    class New < Base
      def call
        @record = model_class.new
        continue = if @controller.respond_to?(:before_new) 
          new_record = @controller.send(:before_new, @record ) 
        else
          true
        end
        if continue
          @record = new_record if new_record && new_record.is_a?(model_class)
          @controller.instance_variable_set :@record, @record
          render_form unless @record.nil?
        end
      end
    end
    
    class Reorder < Base
      def call
        @controller.params["aa_form_table_tbody"].each_with_index { |id,idx| model_class.find(id).update_attribute(@admin_assistant.index_settings.acts_as_list_position_column, idx) }
        @controller.send :render, :text => "Items were succesfully reordered"
      end
      
    end
    
    class Update < Base
      def call
        @record = model_class.find @controller.params[:id]
        @record.attributes = params_for_save
        if save
          redirect_after_update || redirect_after_save
        else
          @controller.instance_variable_set :@record, @record
          render_form
        end
      end
      
      def save
        if @controller.respond_to?(:before_update)
          @controller.send(:before_update, @record)
        end
        result = super
        if @controller.respond_to?(:after_update)
          @controller.send(:after_update, @record)
        end
        result
      end
    end
  end
end
