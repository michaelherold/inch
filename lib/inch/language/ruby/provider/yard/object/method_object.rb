require 'inch/language/ruby/provider/yard/object/method_signature'

module Inch
  module Language
    module Ruby
      module Provider
        module YARD
          module Object
            # Proxy class for methods
            class MethodObject < Base
              UNUSABLE_RETURN_VALUES = %w(nil nothing undefined void)

              def aliases_fullnames
                object.aliases.map(&:path)
              end

              def bang_name?
                name =~ /\!$/
              end

              def constructor?
                name == :initialize
              end

              def getter?
                attr_info = object.attr_info || {}
                read_info = attr_info[:read]
                if read_info
                  read_info.path == fullname
                else
                  parent.child(:"#{name}=")
                end
              end

              def has_code_example?
                signatures.any? { |s| s.has_code_example? }
              end

              def has_doc?
                signatures.any? { |s| s.has_doc? }
              end

              def method?
                true
              end

              def parameters
                @parameters ||= signatures.map(&:parameters).flatten
              end

              def parameter(name)
                parameters.find { |p| p.name == name.to_s }
              end

              # Returns the original docstring unless it was generated by YARD.
              # @return [String]
              def original_docstring
                implicit_docstring? ? "" : super
              end

              def overridden?
                !!object.overridden_method
              end

              def overridden_method
                return unless overridden?
                @overridden_method ||= YARD::Object.for(object.overridden_method)
              end

              def overridden_method_fullname
                return unless overridden?
                overridden_method.fullname
              end

              # Returns +true+ if a return value is described by it's type or
              # mentioned in the docstring (e.g. "Returns a String").
              def return_mentioned?
                return_tags.any? do |t|
                  !t.types.nil? && !t.types.empty? &&
                    !YARD.implicit_tag?(t, self)
                end || docstring.mentions_return? && !implicit_docstring?
              end

              # Returns +true+ if a return value is described by words.
              def return_described?
                return_described_via_tag? ||
                  docstring.describes_return? && !implicit_docstring?
              end

              def return_typed?
                return_mentioned?
              end

              def setter?
                name =~ /\=$/ && parameters.size == 1
              end

              def signatures
                base = MethodSignature.new(self, nil)
                overloaded = overload_tags.map do |tag|
                  MethodSignature.new(self, tag)
                end
                if overloaded.any? { |s| s.same?(base) }
                  overloaded
                else
                  [base] + overloaded
                end
              end

              def questioning_name?
                name =~ /\?$/
              end

              private

              # Returns @return tags that are assigned to the getter
              # corresponding to this setter.
              #
              # @return [Array<::YARD::Tag>]
              def attributed_return_tags
                if setter? && object.tags(:return).empty?
                  method = corresponding_getter
                  return method.object.tags(:return) if method
                end
                []
              end

              # @return [MethodObject,nil]
              def corresponding_getter
                clean_name = name.to_s.gsub(/(\=)$/, '')
                parent.child(clean_name.to_sym)
              end

              # Returns +true+ if the docstring was generated by YARD.
              def implicit_docstring?
                YARD.implicit_docstring?(docstring, self)
              end

              # @return [Array<::YARD::Tag>]
              def overload_tags
                object.tags(:overload)
              end

              # @return [Array<::YARD::Tag>]
              def overloaded_return_tags
                overload_tags.map do |overload_tag|
                  overload_tag.tag(:return)
                end.compact
              end

              # @return [Array<::YARD::Tag>]
              def return_tags
                object.tags(:return) +
                  overloaded_return_tags +
                    attributed_return_tags
              end

              # Returns +true+ if a return value is described by words.
              def return_described_via_tag?
                return_tags.any? do |t|
                  return_tag_describes_unusable_value?(t) ||
                    !t.text.empty? && !YARD.implicit_tag?(t, self)
                end
              end

              def return_tag_describes_unusable_value?(t)
                return false if t.types.nil?
                t.types.size == 1 &&
                  UNUSABLE_RETURN_VALUES.include?(t.types.first)
              end
            end
          end
        end
      end
    end
  end
end
