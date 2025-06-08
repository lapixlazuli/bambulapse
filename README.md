# Bambulapse – Uma solução de timelapses para Impressoras Bambu Lab

O **Bambulapse** é um sistema inteligente de captura de imagem para timelapses externos em impressoras Bambu Lab, utilizando uma câmera USB, sensor ultrassônico HC-SR04 e um Raspberry Pi. Ideal para quem deseja resultados estéticos superiores aos timelapses internos, com mais liberdade de posicionamento e qualidade de imagem.

> ⚠️ Este repositório cobre apenas a parte de software e configuração. A parte de hardware (soldagem, montagem, instalação física) será abordada no site [Makerworld](https://makerworld.com/pt/models/1484429-bambulab-a1-clean-timelapse-with-webcam#profileId-1550596) onde está disponível o STL para colocar o sensor na impressora.

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
git clone https://github.com/lapixlazuli/bambulapse.git
cd bambulapse
```

### 2. Execute o Instalador

```bash
bash install.sh
```

### 3. Configure sua camera

-Rode o comando:
```bash
cd bambulapse
cfgcamera
```
 Veja se a câmera indicada no menu está certa, se não entre na opção 4 do menu para escolher o dispositivo.

```bash
===== Camera Config =====
1) Brightness (0-63): 62
2) Saturation (-100 to 100): 50
3) Snapshot path: /home/lehft/TimelapseShare
4) Video device: Anker PowerConf C200: Anker Pow
5) Resolution: 1920x1090
--------------------------------
1) Apply and save configs
2) Backup restore
3) Exit
================================
Select an option:
```

Digite o número correspondente ao da sua webcam.

```bash
All the USB Device, choose one:
1) C920
2) Anker PowerConf C200: Anker Pow
3) Cancelar
Your choice:
```
Digite o número que for igual ao da sua webcam e depois pressione `ENTER` para voltar ao menu.

Entre no menu `Resolution` digitando `5` e apertando `ENTER`, logo aparecerá algo parecido com isso:

```bash
Searching available pixel formats...
-------------------------
Select the pixel format:
-------------------------
1) MJPG
2) YUYV
3) H264
4) Cancel
Your choice:
```
Selecione o que preferir, mas a recomendação é que seja `MJPG`.

Depois de selecionar o pixel format, selecione a resolução  para sua webcam:

```bash
Searching resolution for MJPG...
-------------------------------------------
Select the resolution for MJPG:
-------------------------------------------
1) 2560x1440
2) 1920x1080
3) 1280x720
4) 640x480
5) 640x360
6) 320x240
7) Cancel
Your choice:
```

Selecionada a resolução, volte ao menu princiapal.
Aplique as configurações digitando `6`

### 3. Configure seu sensor

Agora para configurar seu sensor HC-SR04 rode o comando:

```bash
testdistance
```
Vai aparecer a configuração de distancia padrão, então aparecerá algo como:

```bash
Start test with SNAPSHOT=4.10 e RESET=7.00
Press ENTER to start measure...
```
Ao começar a medição apertando `ENTER`, o sensor começará a medir a distândia do sua impressora, nesse ponto é importante notar que:
   #### *•* Se o sensor medir -1 e aparecer:
```bash
ATTENTION ----> MEASURES <---- ATTENTION
Inside snapshot distance!
Last distance measure: -1 cm
Current snapshot distance config: 4.10 cm
```
   #### *•* Ou se aparecer diversas vezes a mensagem:
```bash
Reading failure.
```
#### *•* Provavelmente seu sensor está com alguma conexão de fio errada ou a alimentação está baixa.

#### Caso o sensor começar a medir certinho, podemos definir as distâncias da seguinte forma:

1. Comece a medição  

![measure1](https://media2.giphy.com/media/v1.Y2lkPTc5MGI3NjExeWUyYTBmdWE4bXJrcW96NHB0ajRkbmcxMnBhNjAwNjVuOTd3bmt0aCZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/yaw9hsDvmckAbLlfTB/giphy.gif)

2.  Agora precisamos posicionar o bico onde acaba a mesa de impressão, para descobrirmos a medida máxima onde o bico pode estar imprimindo
   
![measure2](https://media1.giphy.com/media/v1.Y2lkPTc5MGI3NjExa2psZXR4d3lpbW00a3lwNGMzdnBsNTA2enNoYXpicGpldjh4eW9wMyZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/RVHpC6YTZucSPvTyPT/giphy.gif)

3. Ao posicionar, vamos conferir a medida ideal para colocar no nosso "Reset Distance". Na minha medição ficou próximo de 7,5, então defini como padrão 7,0
   
![measure3](https://media0.giphy.com/media/v1.Y2lkPTc5MGI3NjExZWNpaW5oYzJjdzhidnY1dnliZnQ2aXN6NHMwMmpnaXM5MHgxdjV6eSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/okzReKaSD4Zhk3rrQn/giphy.gif)

4.  Agora, para descobrir a medida final para o sensor saber exatamente o momento de tirar a foto, vamos posicionar o bico no final do sensor e mover levemente, apenas para ter uma folga. Feito isso, basta verificar a medida do sensor. Aqui cheguei ao resultado de 4,2 cm; abaixo disso, a medida do sensor fica meio imprecisa.
   
![measure4](https://media2.giphy.com/media/v1.Y2lkPTc5MGI3NjExMzFtMWJpcm9wZGt2bTF3N3hrbGxzdnR1MjY4Mjl3NTZ5emFvdmxzYSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/kKL3QTBbuCUi5WxgTJ/giphy.gif)

5. Caso tenha que mudar alguma medida, basta rodar o comando `cfgdistance` e alterar as medidas de Snapshot e Reset. (Opção 1 e 2)

```bash
===== Timelapse Distance Configuration =====
1) Snapshot Distance (current: 4.1)
2) Reset Distance    (current: 7.0)
3) Change GPIO TRIG  (current: 2)
4) Change GPIO ECHO  (current: 5)
5) Aplly
6)  exit
============================================
Choose an option:
```

6. Qualquer escolha difrente dos pinos GPIO, também deve ser alterado no `cfgdistance` utilizando os [parâmetros do Wiringpi](https://pinout.xyz/pinout/wiringpi)

#### Agora a parte difícil ja foi, Só falta configurar o timelapse no Bambu Studio.


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
startapse
```
2. Para tirar algum snapshot para testar a webcam: (esse comando só funciona durante o funcionamento do timelapse)
3. 
```bash
snapshot
```

1. Tudo funcionando, pode iniciar a impressão que as imagens vão começar a ser capturadas automaticamente com base na distância medida pelo sensor.

2. Se quiser parar o timelapse, rode:

```bash
stoplapse
```

5. Para alterar as configurações da câmera, só digitar para o Raspberry:

```bash
cfgcamera
```

6. Para testar o sensor hc-sr04, rode o comando:

```bash
testdistance
```

6. Para configurar as medidas do timelapse, rode:

```bash
cfgdistance
```

7. Para acessar a lista de comandos no Raspberry Pi, digite:
   
```bash
bambulapse
```

---

## Futuras Melhorias

- Suporte para outras impressoras Bambu Lab
- Upload automático para serviços em nuvem

---

Feito por [thidiasr] 