module Api
  module V1
    class UnicodeController < ApiController
      def name
        require 'unicode/name'
        
        code_point = params[:code_point]
        
        if code_point.blank?
          render json: { error: 'code_point parameter is required' }, status: :bad_request
          return
        end
        
        begin
          # Handle both hex strings (e.g., "0626") and integers
          if code_point.is_a?(String)
            code_point_int = code_point.to_i(16)
          else
            code_point_int = code_point.to_i
          end
          
          # Get the character from the code point
          begin
            char = code_point_int.chr
          rescue RangeError
            # Invalid code point
            render json: { error: "Invalid Unicode code point: #{code_point}" }, status: :bad_request
            return
          end
          
          name = Unicode::Name.of(char)
          decimal = char.ord
          html_entity_decimal = "&#{decimal};"
          html_entity_hex = "&#x#{code_point_int.to_s(16).upcase};"
          
          # Get decomposition if available
          decomposition = nil
          has_decomposition = false
          begin
            if char.is_a?(String) && char.respond_to?(:unicode_normalize)
              decomposition = char.unicode_normalize(:nfd)
              has_decomposition = decomposition.is_a?(String) && decomposition.size > 1
            end
          rescue => e
            # If decomposition fails, just skip it
            Rails.logger.warn("Failed to get decomposition for code point #{code_point_int}: #{e.message}")
          end
          
          hex_code = code_point_int.to_s(16).upcase.rjust(4, '0')
          
          result = {
            code_point: hex_code,
            name: name,
            html_entity: html_entity_decimal,
            html_entity_hex: html_entity_hex,
            decimal: decimal,
            compart_url: "https://www.compart.com/en/unicode/U+#{hex_code}"
          }
          
          if has_decomposition && decomposition
            result[:decomposition] = decomposition
            result[:decomposition_chars] = decomposition.chars.map { |c| c }
            result[:decomposition_hex] = decomposition.chars.map { |c| c.ord.to_s(16).upcase.rjust(4, '0') }
          end
          
          render json: result
        rescue LoadError => e
          render json: { error: 'Unicode name gem not available' }, status: :internal_server_error
        rescue => e
          render json: { error: e.message }, status: :internal_server_error
        end
      end

      def init_presenter

      end
    end
  end
end

