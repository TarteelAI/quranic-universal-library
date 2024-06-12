namespace :download_timing do
=begin
task download_timing_file: :environment do
  base_url = "https://android.quran.com/data/databases/audio/"
  files = %w[
  abdulaziz_zahrani.zip
  abdul_basit_mujawwad.zip
  abdul_basit_murattal.zip
  abdullah_basfar.zip
  abdullah_juhany.zip
  abdullah_matroud.zip
  abdul_muhsin_alqasim.zip
  abdulrahman_alshahat.zip
  abdurrashid_sufi.zip
  ahmad_nauina.zip
  ahmed_al3ajamy.zip
  akram_al_alaqmi.zip
  ali_hajjaj_alsouasi.zip
  ali_jaber.zip
  aziz_alili.zip
  bandar_baleela.zip
  fares_abbad.zip
  hani_rifai.zip
  husary_iza3a.zip
  husary.zip
  ibrahim_walk.zip
  khalifa_taniji.zip
  maher_al_muaiqly.zip
  mahmoud_ali_albana.zip
  minshawi_murattal.zip
  mishari_alafasy_cali.zip
  mishari_alafasy.zip
  mishari_walk.zip
  mjibreel.zip
  mohammad_altablawi.zip
  mostafa_ismaeel.zip
  muhammad_ayyoub.zip
  qatami.zip
  sa3d_alghamidi.zip
  sahl_yaseen.zip
  salah_budair.zip
  salah_bukhatir.zip
  shatri.zip
  shuraym.zip
  sudais_murattal.zip
  yasser_dussary.zip
 ]

  files.each do |file|
    response = with_rescue_retry([RestClient::Exceptions::ReadTimeout], retries: 3, raise_exception_on_limit: true) do
      RestClient.get("#{base_url}#{file}")
    end

    File.open("data/timing/#{file}", "wb") do |f|
      f << response.body
    end
  end
end
=end
end