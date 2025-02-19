module Importer
  class TafsirApp < Base
    #TODO: https://tafsir.app/aliraab-almuyassar/2/37
    # https://tafsir.app/iraab-daas/2/33
    # https://tafsir.app/aljadwal/2/33
    # https://tafsir.app/aldur-almasoon/2/33
    # https://tafsir.app/lubab/2/33
    # https://tafsir.app/qiraat-almawsoah/2/33
    # https://tafsir.app/alnashir/2/33
    # https://tafsir.app/iraab-aldarweesh/2/33

    TAFISR_MAPPING = {
      'aliraab-almuyassar' => '',
      'iraab-daas' => '',
      'aljadwal'  => '',
      'aldur-almasoon' => '',
      'lubab' => '',
      'qiraat-almawsoah' => '',
      'alnashir' => '',
      'iraab-aldarweesh' => '',
      'ibn-katheer' => '',
      'tabari' => '',
      'qurtubi' => '',
      'baghawi' => '',
      'muyassar' => '',
      'saadi' => '',
      'almuyassar-ghareeb' => ''
    }

    def import(key)
      "https://tafsir.app/get.php?src=ibn-katheer&s=5&a=99&ver=1"
    end
  end
end