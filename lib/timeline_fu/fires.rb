module TimelineFu
  module Fires
    def self.included(klass)
      klass.send(:extend, ClassMethods)
    end

    module ClassMethods
      def fires(event_type, opts)
        raise ArgumentError, "Argument :on is mandatory" unless opts.has_key?(:on)

        # Array provided, set multiple callbacks
        if opts[:on].kind_of?(Array)
          opts[:on].each { |on| fires(event_type, opts.merge({:on => on})) }
          return
        end

        opts[:subject] = :self unless opts.has_key?(:subject)

        on = opts.delete(:on)
        _if = opts.delete(:if)
        _unless = opts.delete(:unless)

        event_class_names = Array(opts.delete(:event_class_name) || "TimelineEvent")

        method_name = :"fire_#{event_type}_after_#{on}"
        define_method(method_name) do
          create_options = opts.keys.inject({}) do |memo, sym|
            if opts[sym]
              if opts[sym].respond_to?(:call)
                memo[sym] = opts[sym].call(self)
              elsif opts[sym] == :self
                memo[sym] = self
              else
                memo[sym] = send(opts[sym])
              end
            end
            memo
          end
          create_options[:event_type] = event_type.to_s

          event_class_names.each do |class_name|
            class_name.classify.constantize.create!(create_options)
          end
        end

        if respond_to?(:"after_#{on}")
          send(:"after_#{on}", method_name, :if => _if, :unless => _unless)
        else
          define_method(:"#{on}_with_fire") do |*args|
            send("#{on}_without_fire", *args)

            do_not_fire = _if && !_if.call(self)
            do_not_fire ||= _unless && _unless.call(self)
            send(method_name) unless do_not_fire
          end

          begin
            alias_method_chain on, :fire
          rescue NameError
            raise "undefined method `#{on}' for class `#{name}'. Make sure to call `fires' after defining the method."
          end
        end
      end
    end
  end
end
