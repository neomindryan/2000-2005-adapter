module ActiveRecord
  module ConnectionAdapters
    module SQLServerActiveRecordExtensions
      
      def self.included(klass)
        klass.extend ClassMethods
        class << klass
          alias_method_chain :reset_column_information, :sqlserver_cache_support
          alias_method_chain :add_order!, :sqlserver_unique_checking
        end
      end
      
      module ClassMethods
        
        def execute_procedure(proc_name, *variables)
          if connection.respond_to?(:execute_procedure)
            connection.execute_procedure(proc_name,*variables)
          else
            []
          end
        end
        
        def coerce_sqlserver_date(*attributes)
          write_inheritable_attribute :coerced_sqlserver_date_columns, Set.new(attributes.map(&:to_s))
        end
        
        def coerce_sqlserver_time(*attributes)
          write_inheritable_attribute :coerced_sqlserver_time_columns, Set.new(attributes.map(&:to_s))
        end
        
        def coerced_sqlserver_date_columns
          read_inheritable_attribute(:coerced_sqlserver_date_columns) || []
        end
        
        def coerced_sqlserver_time_columns
          read_inheritable_attribute(:coerced_sqlserver_time_columns) || []
        end
        
        def reset_column_information_with_sqlserver_cache_support
          connection.send(:initialize_sqlserver_caches) if connection.respond_to?(:sqlserver?)
          reset_column_information_without_sqlserver_cache_support
        end
        
        private
        
        def add_order_with_sqlserver_unique_checking!(sql, order, scope = :auto)
          if connection.respond_to?(:sqlserver?)
            order_sql = ''
            add_order_without_sqlserver_unique_checking!(order_sql, order, scope)
            unless order_sql.blank?
              unique_order_hash = {}
              select_table_name = connection.send(:get_table_name,sql)
              select_table_name.tr!('[]','') if select_table_name
              orders_and_dirs_set = connection.send(:orders_and_dirs_set,order_sql)
              unique_order_sql = orders_and_dirs_set.inject([]) do |array,order_dir|
                ord, dir = order_dir
                ord_tn_and_cn = ord.to_s.split('.').map{|o|o.tr('[]','')}
                ord_table_name, ord_column_name = if ord_tn_and_cn.size > 1
                                                    ord_tn_and_cn
                                                  else
                                                    [nil, ord_tn_and_cn.first]
                                                  end
                if (ord_table_name && ord_table_name == select_table_name && unique_order_hash[ord_column_name]) || unique_order_hash[ord_column_name]
                  array
                else
                  unique_order_hash[ord_column_name] = true
                  array << "#{ord} #{dir}".strip
                end
              end.join(', ')
              sql << " ORDER BY #{unique_order_sql}"
            end
          else
            add_order_without_sqlserver_unique_checking!(sql, order, scope)
          end
        end
        
      end
      
    end
  end
end

ActiveRecord::Base.send :include, ActiveRecord::ConnectionAdapters::SQLServerActiveRecordExtensions
