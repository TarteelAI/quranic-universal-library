# i = Importer::QuranKsuEduTafsir.new
# i.download
# https://surahquran.com/tafsir-shawkani/altafsir.html
# https://surahquran.com/tafsir-shanqiti/altafsir.html
module Importer
  class QuranTafsirNet < Base
    NMAE_MAPPING = {
      qotb: {
        name: "في ظلال القرآن لسيد قطب - سيد قطب"
      },
      baidawy: {
        name: "أنوار التنزيل وأسرار التأويل للبيضاوي - البيضاوي"
      },
      atia: {
        name: "المحرر الوجيز في تفسير الكتاب العزيز لابن عطية - ابن عطية"
      },
      tantawy: {
        name: "التفسير الوسيط للقرآن الكريم لسيد طنطاوي - سيد طنطاوي"
      },
      "tantawy-baghawy": {
        name: "معالم التنزيل في تفسير القرآن الكريم للبغوي - البغوي"
      },
      ashour: {
        name: "التحرير والتنوير لابن عاشور - ابن عاشور"
      },
      saady: {
        name: "تيسير الكريم المنان في تفسير القرآن لابن سعدي - ابن سعدي"
      },
      fareed: {
        name: " المصحف المفسّر لفريد وجدي - فريد وجدي"
      },
      qasimi: {
        name: " محاسن التأويل للقاسمي - القاسمي"
      },
      seddiq: {
        name: " فتح البيان في مقاصد القرآن للقنوجي - صديق حسن خان"
      },
      alusy: {
        name: " روح المعاني في تفسير القرآن والسبع المثاني للآلوسي - الآلوسي"
      },
      montakhab: {
        name: "المنتخب في تفسير القرآن الكريم للمجلس الأعلى للشؤون الإسلامية - المنتخب"
      },
      baghawy: {
        name: " معالم التنزيل في تفسير القرآن الكريم للبغوي - البغوي"
      },
      katheer: {
        name: " تفسير القرآن العظيم لابن كثير - ابن كثير"
      },
      mobdii: {
        name: " الجامع التاريخي لبيان القرآن الكريم - مركز مبدع"
      },
      tabary: {
        name: " جامع البيان عن تأويل آي القرآن للطبري - الطبري"
      },
      "montakhab-baghawy-saady-tantawy-qotb-katheer-tabary-baidawy-atia-ashour-mobdii": {
        name: " المنتخب في تفسير القرآن الكريم للمجلس الأعلى للشؤون الإسلامية - المنتخب"
      },
      moqatel: {
        name: " تفسير مقاتل بن سليمان - مقاتل"
      },
      farraa: {
        name: " معاني القرآن للفراء - الفراء"
      },
      maturidy: {
        name: " تأويلات أهل السنة للماتريدي - الماتريدي"
      },
      samarqandy: {
        name: " بحر العلوم لعلي بن يحيى السمرقندي - السمرقندي"
      },
      zamanen: {
        name: " تفسير ابن أبي زمنين - ابن أبي زمنين"
      },
      taalaby: {
        name: " الكشف والبيان في تفسير القرآن للثعلبي - الثعلبي"
      },
      makky: {
        name: " الهداية إلى بلوغ النهاية لمكي بن ابي طالب - مكي ابن أبي طالب"
      },
      mawardy: {
        name: " النكت و العيون للماوردي - الماوردي"
      },
      qoshairy: {
        name: " لطائف الإشارات للقشيري - القشيري"
      },
      wahidy: {
        name: " الوجيز في تفسير الكتاب العزيز للواحدي - الواحدي"
      },
      zamakhshary: {
        name: " الكشاف عن حقائق التنزيل للزمخشري - الزمخشري"
      },
      alrazy: {
        name: " مفاتيح الغيب للرازي - الفخر الرازي"
      },
      alez: {
        name: " تفسير العز بن عبد السلام - العز بن عبد السلام"
      },
      qortoby: {
        name: " الجامع لأحكام القرآن للقرطبي - القرطبي"
      },
      nasafy: {
        name: " مدارك التنزيل وحقائق التأويل للنسفي - النسفي"
      },
      khazen: {
        name: " لباب التأويل في معاني التنزيل للخازن - الخازن"
      },
      jezzy: {
        name: " التسهيل لعلوم التنزيل، لابن جزي - ابن جزي"
      },
      hayyan: {
        name: " البحر المحيط لأبي حيان الأندلسي - أبو حيان"
      },
      halaby: {
        name: " الدر المصون في علم الكتاب المكنون للسمين الحلبي - السمين الحلبي"
      },
      naisabory: {
        name: " غرائب القرآن ورغائب الفرقان للحسن بن محمد النيسابوري - النيسابوري- الحسن بن محمد"
      },
      thaaliby: {
        name: " الجواهر الحسان في تفسير القرآن للثعالبي - الثعالبي"
      },
      adel: {
        name: " اللباب في علوم الكتاب لابن عادل - ابن عادل"
      },
      beqaay: {
        name: " نظم الدرر في تناسب الآيات و السور للبقاعي - البقاعي"
      },
      eejy: {
        name: " جامع البيان في تفسير القرآن للإيجي - الإيجي محيي الدين"
      },
      jalalen: {
        name: " تفسير الجلالين  للمحلي والسيوطي - تفسير الجلالين"
      },
      seoty: {
        name: " الدر المنثور في التفسير بالمأثور للسيوطي - السيوطي"
      },
      sherbiny: {
        name: " السراج المنير في تفسير القرآن الكريم للشربيني - الشربيني"
      },
      sood: {
        name: " إرشاد العقل السليم إلى مزايا الكتاب الكريم لأبي السعود - أبو السعود"
      },
      aaqam: {
        name: " تفسير الأعقم - الأعقم"
      },
      shawkany: {
        name: " فتح القدير الجامع بين فني الرواية والدراية من علم التفسير للشوكاني - الشوكاني"
      },
      darwazeh: {
        name: " التفسير الحديث لدروزة - دروزة"
      },
      qattan: {
        name: " تيسير التفسير لإبراهيم القطان - إبراهيم القطان"
      },
      makhloof: {
        name: " صفوة البيان لحسين مخلوف - حسنين مخلوف"
      },
      jazaery: {
        name: " أيسر التفاسير لكلام العلي الكبير للجزائري - أبوبكر الجزائري"
      },
      toalab: {
        name: " فتح الرحمن في تفسير القرآن لتعيلب - تعيلب"
      },
      moyassar: {
        name: " التفسير الميسر لمجموعة من العلماء - التفسير الميسر"
      },
      amir: {
        name: " التفسير الشامل لأمير عبد العزيز - أمير عبد العزيز"
      },
      basheer: {
        name: " التفسير الصحيح لبشير  ياسين - بشير ياسين"
      },
      shehata: {
        name: " تفسير القرآن الكريم لعبد الله شحاته - شحاته"
      }
    }

    def download_all
      NMAE_MAPPING.each do |key, value|
        download(key)
      end
    end

    # https://quran-tafsir.net/qotb/sura1-aya4.html
    def download(key)
      FileUtils.mkdir_p("data/quran-tafsir-net/#{key}")
      Verse.order('id asc').find_each do |v|
        url = "https://quran-tafsir.net/#{key}/sura#{v.chapter_id}-aya#{v.verse_number}.html"

        next if File.exist?("data/quran-tafsir-net/#{key}/#{v.verse_key}.html")

        File.open("data/quran-tafsir-net/#{key}/#{v.verse_key}.html", "wb") do |file|
          text = get_html(url).body
          file.puts text

          puts "#{key} #{v.verse_key}"
        end
      end
    end

    def import

    end
  end
end