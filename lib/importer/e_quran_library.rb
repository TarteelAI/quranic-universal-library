=begin
i = Importer::EQuranLibrary.new
keys = Importer::EQuranLibrary::TAFSIRS.keys
keys.each do |key|
  i.download key.to_s
end
=end
module Importer
  class EQuranLibrary < Base
    TAFSIRS = {
      ibnekaseer: {
        id: '',
        skip: true,
        name: 'Tafseer Ibn-e-Kaseer',
        native: 'تفسیر ابنِ کثیر',
        author: 'مولانا محمد جوناگڑہی',
        translated: true
      },
      maarifulquran: {
        id: '',
        name: 'Maarif-ul-Quran',
        native: 'معارف القرآن',
        author: 'مفتی محمد شفیع'
      },
      tafheemulquran: {
        id: '',
        name: 'Tafheem-ul-Quran',
        native: 'تفہیم القرآن',
        author: 'سید ابو الاعلیٰ مودودی'
      },
      tadabburequran: {
        id: '',
        name: 'Tadabbur-e-Quran',
        native: 'تدبرِ قرآن',
        author: 'مولانا امین احسن اصلاحی'
      },
      ahsanulbayan: {
        id: '',
        name: 'Ahsan-ul-Bayan',
        native: 'احسن البیان',
        author: 'مولانا صلاح الدین یوسف'
      },
      aasantarjumaquran: {
        id: '',
        name: 'Aasan Quran',
        native: 'آسان قرآن',
        author: 'مفتی محمد تقی عثمانی',
        pdf: 'https://drive.google.com/file/d/0B9kHqDDK6NaXMlo5d01CbWN0Qkk/view?resourcekey=0-tbaR6PwZUsmYMumoA7uZ_g'
      },
      fizilalalquran: {
        id: '',
        name: 'Fi-Zilal-al-Quran',
        native: 'فی ظلال القرآن',
        author: 'سید قطب',
        pdf: 'https://archive.org/details/FiZilalAlQuranUrdu/Fi%20Zilal%20al%20Qur%E2%80%99an%20part%201/page/n5/mode/2up'
      },
      usmani: {
        id: '',
        name: 'Tafseer-e-Usmani',
        native: 'تفسیرِ عثمانی',
        author: 'مولانا شبیر احمد عثمانی'
      },
      bayanulquran: {
        id: '',
        name: 'Bayan-ul-Quran',
        native: 'تفسیر بیان القرآن',
        author: 'ڈاکٹر اسرار احمد'
      },
      taiseerulquran: {
        id: '',
        name: 'Taiseer-ul-Quran',
        native: 'تیسیر القرآن',
        author: 'مولانا عبد الرحمٰن کیلانی'
      },
      majidi: {
        id: '',
        name: 'Tafseer-e-Majidi',
        native: 'تفسیرِ ماجدی',
        author: 'مولانا عبد الماجد دریابادی'
      },
      jalalain: {
        id: '',
        name: 'Tafseer e Jalalain',
        native: 'تفسیرِ جلالین',
        author: 'امام جلال الدین السیوطی'
      },
      mazhari: {
        id: '',
        name: 'Tafseer e Mazhari',
        native: 'تفسیرِ مظہری',
        author: 'قاضی ثنا اللہ پانی پتی'
      },
      ibneabbas: {
        id: '',
        name: 'Tafseer IbneAbbas',
        native: 'تفسیر ابن عباس',
        author: 'حافظ محمد سعید احمد عاطف',
        translated: true
      },
      alquranalkareem: {
        id: '',
        name: 'Al-Quran-al-Kareem',
        native: 'تفسیر القرآن الکریم',
        author: 'مولانا عبدالسلام بھٹوی'
      },
      tibyanulquran: {
        id: '',
        name: 'Tibyan-ul-Quran',
        native: 'تفسیر تبیان القرآن',
        author: 'مولانا غلام رسول سعیدی'
      },
      qurtubi: {
        id: '',
        name: 'Al-Qurtubi',
        native: 'تفسیر القرطبی',
        author: 'ابو عبدالله القرطبي'
      },
      duremansoor: {
        id: '',
        name: 'Dure-Mansoor',
        native: 'تفسیر درِ منثور',
        author: 'امام جلال الدین السیوطی'
      },
      mutaliyaquran: {
        id: '',
        name: 'Mutaliya-e-Quran',
        native: 'تفسیر مطالعہ قرآن',
        author: 'پروفیسر حافظ احمد یار'
      },
      anwarulbayan: {
        id: '',
        name: 'Anwar-ul-Bayan',
        native: 'تفسیر انوار البیان',
        author: 'مولانا عاشق الٰہی مدنی'
      },
      maarifulqurankandhalwi: {
        id: '',
        name: 'Maarif-ul-Quran',
        native: 'معارف القرآن',
        author: 'مولانا محمد ادریس کاندھلوی'
      },
      jawahirulquran: {
        id: '',
        name: 'Jawahir-ul-Quran',
        native: 'جواھر القرآن',
        author: 'مولانا غلام اللہ خان'
      },
      mualimulirfan: {
        id: '',
        name: 'Mualim-ul-Irfan',
        native: 'معالم العرفان',
        author: 'مولانا عبدالحمید سواتی'
      },
      mufradatulquran: {
        id: '',
        name: 'Mufradat-ul-Quran',
        native: 'مفردات القرآن',
        author: 'مولانا عبدہ فیروزپوری',
        translated: true
      },
      haqqani: {
        id: '',
        name: 'Tafseer-e-Haqqani',
        native: 'تفسیرِ حقانی',
        author: 'مولانا محمد عبدالحق حقانی'
      },
      ruhulquran: {
        id: '',
        name: 'Ruh-ul-Quran',
        native: 'روح القرآن',
        author: 'ڈاکٹر محمد اسلم صدیقی'
      },
      fahmulquran: {
        id: '',
        name: 'Fahm-ul-Quran',
        native: 'فہم القرآن',
        author: 'میاں محمد جمیل'
      },
      madarikuttanzil: {
        id: '',
        name: 'Madarik-ut-Tanzil',
        native: 'مدارک التنزیل',
        author: 'فتح محمد جالندھری',
        translated: true
      },
      baghwi: {
        id: '',
        name: 'Tafseer-e-Baghwi',
        native: 'تفسیرِ بغوی',
        author: 'حسین بن مسعود البغوی'
      },
      ahsanuttafaseer: {
        id: '',
        name: 'Ahsan-ut-Tafaseer',
        native: 'احسن التفاسیر',
        author: 'حافظ محمد سید احمد حسن'
      },
      saadi: {
        id: '',
        name: 'Tafseer-e-Saadi',
        native: 'تفسیرِ سعدی',
        author: 'عبدالرحمٰن ابن ناصر السعدی'
      },
      ahkamulquran: {
        id: '',
        name: 'Ahkam-ul-Quran',
        native: 'احکام القرآن',
        author: 'امام ابوبکر الجصاص'
      },
      madani: {
        id: '',
        name: 'Tafseer-e-Madani',
        native: 'تفسیرِ مدنی',
        author: 'مولانا اسحاق مدنی'
      },
      mafhoomulquran: {
        id: '',
        name: 'Mafhoom-ul-Quran',
        native: 'مفہوم القرآن',
        author: 'محترمہ رفعت اعجاز'
      },
      asratuttanzil: {
        id: '',
        name: 'Asrar-ut-Tanzil',
        native: 'اسرار التنزیل',
        author: 'مولانا محمد اکرم اعوان'
      },
      ashrafulhawashi: {
        id: '',
        name: 'Ashraf-ul-Hawashi',
        native: 'اشرف الحواشی',
        author: 'شیخ محمد عبدالفلاح'
      },
      anwarulbayanali: {
        id: '',
        name: 'Anwar-ul-Bayan',
        native: 'تفسیر انوار البیان',
        author: 'مولانا عاشق الٰہی مدنی'
      },
      baseeratequran: {
        id: '',
        name: 'Baseerat-e-Quran',
        native: 'بصیرتِ قرآن',
        author: 'مولانا محمد آصف قاسمی'
      },
      mazharulquran: {
        id: '',
        name: 'Mazhar-ul-Quran',
        native: 'مظہر القرآن',
        author: 'شاہ محمد مظہر اللہ دہلوی'
      },
      tafseeralkitaab: {
        id: '',
        name: 'Tafseer-al-Kitaab',
        native: 'تفسیر الکتاب',
        author: 'ڈاکٹر محمد عثمان'
      },
      sirajulbayan: {
        id: '',
        name: 'Siraj-ul-Bayan',
        native: 'سراج البیان',
        author: 'علامہ محمد حنیف ندوی'
      },
      kashfurrahman: {
        id: '',
        name: 'Kashf-ur-Rahman',
        native: 'کشف الرحمٰن',
        author: 'مولانا احمد سعید دہلوی'
      },
      bayanulquranthanvi: {
        id: '',
        name: 'Bayan-ul-Quran',
        native: 'بیان القرآن',
        author: 'مولانا اشرف علی تھانوی'
      },
      urwatulwusqa: {
        id: '',
        name: 'Urwatul-Wusqaa',
        native: 'عروۃ الوثقٰی',
        author: 'علامہ عبدالکریم اسری'
      },
      maarifulquranenglish: {
        id: '',
        name: 'Maarif-ul-Quran',
        author: 'مفتی محمد شفیع',
        language: 'en'
      },
      tafheemulquranen: {
        id: '',
        name: 'Tafheem-ul-Quran',
        author: 'سید ابو الاعلیٰ مودودی',
        language: 'en'
      }
    }

    def download(key)
      return if TAFSIRS[key.to_sym][:skip]
      FileUtils.mkdir_p("data/equranlibrary/#{key}")

      1.upto(114).each do |c|
        download_chapter(c, key)
      end
    end

    protected

    def download_chapter(chapter_id, key)
      Verse.where(chapter_id: chapter_id).order('verse_number asc').each do |v|
        next if File.exist?("data/equranlibrary/#{key}/#{v.verse_key}.json")

        File.open("data/equranlibrary/#{key}/#{v.verse_key}.html", "wb") do |file|
          doc = fetch_tafsir(key, v)
          result = doc.body.gsub('<head id="j_idt6">', "<head><meta charset='utf-8'>")
          file.puts result

          puts "#{key} #{v.verse_key}"
        end
      end
    end

    def fetch_tafsir(key, verse)
      url = "http://equranlibrary.com/tafseer/#{key}/#{verse.chapter_id}/#{verse.verse_number}"
      get_html(url)
    rescue RestClient::NotFound
      log_message "#{key} Tafsir is missing for ayah #{verse.verse_key}. #{url}"
      ""
    end
  end
end
