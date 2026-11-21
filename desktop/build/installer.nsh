; Vodoo Music - NSIS ozel makrolari
; Amac: kaldirma sirasinda uygulama aciksa dosya kilitleri yuzunden artik
; dosyalar kalmasin. Once surec kapatilir, kisa bekleme sonrasi silme yapilir.

!macro customUnInit
  DetailPrint "Vodoo Music kapatiliyor..."
  nsExec::ExecToLog 'taskkill /F /T /IM "${APP_EXECUTABLE_FILENAME}"'
  Sleep 1500
!macroend

!macro customUnInstall
  ; Kaldirma sonrasi bos kalan klasoru de temizle (kullanici verisi korunur).
  ; SetOutPath sart: aksi halde uninstaller $INSTDIR icinde calisir ve
  ; klasor silinemez (bos klasor kalir).
  SetOutPath "$TEMP"
  RMDir "$INSTDIR"
!macroend
