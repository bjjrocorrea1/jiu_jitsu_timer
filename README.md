# Jiu-Jitsu Timer (Flutter)

Timer simples para rolas com ciclos automáticos, descanso, contador de rolas concluídos e bipe sonoro.

## Requisitos
- Flutter instalado no Windows
- Android Studio/Android SDK configurado para compilar para Android
- Celular ou tablet Android com depuração USB habilitada para instalar diretamente

## Como abrir no VS Code
1. Extraia `jiu_jitsu_timer.zip` para uma pasta fácil de encontrar, por exemplo `C:\projetos\jiu_jitsu_timer`.
2. No VS Code, escolha **File > Open Folder** e abra a pasta `jiu_jitsu_timer` (a pasta que contém `pubspec.yaml`).
3. Abra **Terminal > New Terminal**.
4. Gere os arquivos de plataforma do Flutter para esta pasta com `flutter create .` (isso cria a estrutura Android necessária sem apagar o código em `lib`).
5. Execute, uma linha por vez:

```powershell
flutter doctor
flutter pub get
flutter analyze
flutter run
```

Se `flutter doctor` apontar problema no Android toolchain, corrija-o antes de executar `flutter run`.

## Instalar no tablet
1. Ative as opções do desenvolvedor e a depuração USB no tablet.
2. Conecte-o ao computador e aceite a autorização que aparecer no tablet.
3. No terminal do VS Code, execute `flutter devices` e confirme que o tablet aparece.
4. Execute `flutter run` para instalar e abrir o app.
5. Para gerar um APK de instalação, execute `flutter build apk --release`. O arquivo será criado em `build\app\outputs\flutter-apk\app-release.apk`.

## Como usar
1. Escolha a duração do rola, o descanso e o número de rolas.
2. Toque em **COMEÇAR TREINO**.
3. O timer alterna automaticamente entre rola e descanso, toca bipes e conta os rolas concluídos.
4. Use **PAUSAR/CONTINUAR** quando precisar.
5. Use **REINICIAR CONTAGEM** para zerar a sessão.

## Observações
- O bipe é um arquivo WAV local; não precisa de internet.
- O app tenta manter a tela ligada durante a sessão.
- Fechar o app ou o sistema encerrar o processo pode interromper o timer. Esta primeira versão foi pensada para permanecer aberta em primeiro plano durante o treino.
- Para testar: rode `flutter analyze`, depois `flutter run` e confira os bipes, a pausa, o descanso e o encerramento do último rola.
