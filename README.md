# Bambulapse – Uma solução de timelapses para Impressoras Bambu Lab

O **Bambulapse** é um sistema inteligente de captura de imagem para timelapses externos em impressoras Bambu Lab, utilizando uma câmera USB, sensor ultrassônico HC-SR04 e um Raspberry Pi. Ideal para quem deseja resultados estéticos superiores aos timelapses internos, com mais liberdade de posicionamento e qualidade de imagem.

> ⚠️ Este repositório cobre apenas a parte de software e configuração. A parte de hardware (soldagem, montagem, instalação física) será abordada no site [Makerworld](https://makerworld.com/) <!-- colocar link do stl no makerworld --> onde está disponível o STL para colocar o sensor na impressora.

---

## Motivação

As câmeras integradas nas impressoras Bambu Lab nem sempre agradam os usuários devido à qualidade ou posicionamento fixo. Devido ao sistema fechado da Bambu e seu G-code proprietário (AMS), as opções para timelapse externo são bastante limitadas.

Este projeto oferece uma alternativa: capturar imagens com precisão e sincronização, usando alterações mínimas no G-code e hardware acessível.

---

## Requisitos

- Raspberry Pi (ou qualquer SBC compatível com GPIO e Linux)
- Webcam USB compatível com `v4l2`
- Sensor HC-SR04
- Impressora Bambu Lab A1 Combo
- Conexão de rede com seu PC (preferencialmente via SAMBA)

---

## Instalação

### 1. Clone o Repositório

```bash
git clone https://github.com/lapixlazuli/bambulapse
cd bambulapse
```

### 2. Configure o Script

Edite o arquivo `config.sh` com os seguintes parâmetros:

```bash
sudo nano config.sh
```
- `video device`: é o número do seu dispositivo de video que foi reconhecido pelo Raspberry pi, obtido com o comando:

```bash
v4l2-ctl --device=/dev/video0 --list-formats-ext
```
- `width` e `height`: resolução suportada pela sua webcam
- `pixel_format`: obtido com o comando:

```bash
v4l2-ctl --device=/dev/video0 --list-formats-ext
```
utilizando o [padrão do motion](https://motion-project.github.io/4.5.1/motion_config.html#video_params):
| Pixel Format | v4l2_palette |
|:------------:|:------------:|
| S910         | 0            |
| BYR2         | 1            |
| BA81         | 2            |
| S561         | 3            |
| GBRG         | 4            |
| GRBG         | 5            |
| P207         | 6            |
| PJPG         | 7            |
| MJPG         | 8            |
| JPEG         | 9            |
| RGB3         | 10           |
| S501         | 11           |
| S505         | 12           |
| S508         | 13           |
| UYVY         | 14           |
| YUYV         | 15           |
| 422P         | 16           |
| YU12         | 17           |
| Y10          | 18           |
| Y12          | 19           |
| GREY         | 20           |

- `DIR`: pasta onde as imagens serão salvas (pode ser um diretório do cartão sd ou diretório compartilhado via SAMBA)
- `GPIO_TRIG` e `GPIO_ECHO`: pinos GPIO do Raspberry Pi usados com base no padrão [WiringPi](https://pinout.xyz/pinout/wiringpi).

### 3. Execute o Instalador

```bash
bash install.sh
```

---

### Configuração do G-code da Bambu Lab

1. No **Bambu Studio**, vá em:
   - **Editar impressora > Machine G-code > Time lapse G-code**
2. Localize este trecho:

```gcode
G1 X-48.2 F3000 ; move to safe pos
M400
M1004 S5 P1 ; external shutter
M400 P300
```
![gcode](https://media4.giphy.com/media/v1.Y2lkPTc5MGI3NjExbGNhZWozanF5Y2s1b2w0Y2N0dTVvZ3R1ZmMzM3J2cTlzZG9jZWx2ayZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/k0qQLNK3lDNMutBMyO/giphy.gif)

3. **Modifique a linha `M400 P300` para:**

```gcode
M400 P2800
```

Isso aumenta o tempo de pausa para capturar a imagem.

> Salve como um novo perfil de impressora para manter o original intacto.

4. Ative as opções:
   - `Smooth Timelapse`
   - `Prime Tower` (**ESSENCIAL!** Sem ela, sua impressão sairá com muitos fiapos)

   ![prime tower](https://media2.giphy.com/media/v1.Y2lkPTc5MGI3NjExMzVnM2hkNzZkbTRoZm5kdWVzZm0wdWF2aHQ1aWs4M3UwenZ3eXRwNyZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/Ffg8lsrrdm19S8ZGxD/giphy.gif)

---

## Como Usar
1. Pode iniciar o script do timelapse digitando para o Raspberry:
```bash
start-timelapse
```
2. Para testar se a webcam está funcionando da forma que gostaria, digite para o Raspberry:
```bash
snapshot
```
3. Tudo funcionando, pode iniciar a impressão que as imagens vão começar a ser capturadas automaticamente com base na distância medida pelo sensor.

4. Se quiser parar o timelapse, rode:

```bash
sudo stop-timelapse
```
5. Para alterar as configurações da câmera, só digitar para o Raspberry:

```bash
config-camera
```

---

## Futuras Melhorias

- Suporte para outras impressoras Bambu Lab
- Upload automático para serviços em nuvem

---

Feito por [thidiasr] 