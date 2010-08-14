class AdminAssistant
  module Helper
    def admin_assistant_includes
      stylesheet_link_tag 'admin_assistant'
    end
    
    def remebered_get_params_without( ignore = [], controller_params = nil )
      r_params = controller_params || params
      
      if @admin_assistant
        as = @admin_assistant
      elsif @controller && @controller.admin_assistant
        as = @controller.admin_assistant
      elsif self && self.admin_assistant
        as = self.admin_assistant
      end
      
      get_params = {}
      as.index_settings.remember_params.each do |rem_par| 
        get_params[rem_par] = r_params[rem_par] if r_params[rem_par] && !ignore.include?( rem_par )
      end
      get_params
    end
    
    def return_to_get_params_without( ignore = [], controller_params = nil )
      get_params = remebered_get_params_without( ignore, controller_params )
      get_params[:return_to] = request.request_uri.gsub(/\?.*$/,'')
      get_params
    end
    
    def remembered_hidden_fields_without( ignore = [] )
      hidden_fields = ""
      @admin_assistant.index_settings.remember_params.each do |rem_par| 
        hidden_fields << hidden_field_tag( rem_par.to_s, params[rem_par] ) if params[rem_par] && !ignore.include?( rem_par )
      end
      hidden_fields
    end
    
  end
  
end
