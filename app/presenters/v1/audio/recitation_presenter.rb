module V1
  module Audio
    class RecitationPresenter < BasePresenter
      def ayah_recitations
        ::Recitation
          .approved
          .includes(:recitation_style, :qirat_type)
      end

      def surah_recitations
        ::Audio::Recitation
          .approved
          .includes(:recitation_style, :qirat_type)
      end
    end
  end
end