# Assets del invernadero (Martians, Base Ares 1)

Todo a 1280x720. Las rutas sugeridas en el proyecto: `assets/interiores/estacion_ares1/invernadero/`.

## escena/  (invernadero en tercera persona)
- `invernadero_base.png`: fondo de la sala (3 camas, tanque, panel, composta, estantes de semillas y abono, puerta a la izquierda).
- `invernadero_layout.json`: posiciones de camas, lamparas, estaciones (semillas, abono, composta...) y salida.
- `build_greenhouse.py`: script que genera la imagen.

## fondos/  (vista cenital de las 3 camas, 24 huecos: 3 camas x 4 filas x 2 columnas)
- `fondo_vacio.png`: huecos vacios. Base para SEMBRAR, REGAR y QUITAR PLANTAS.
- `fondo_brotes.png`: con brotes. Sirve para cambiar de fondo al terminar de sembrar.
- `fondo_plantas.png`: con plantas grandes (las plantas estan pintadas en el fondo).

## sembrar/
- `semilla.png` (535x473) y `semilla_32.png` (32 px de ancho): la papa-semilla con transparencia.
- `huecos_layout.json`: centro (x, y) de los 24 huecos en px de 1280x720. Lo usan SEMBRAR y REGAR.
- `prep_siembra_imgs.py`: script que genero estos archivos a partir de las imagenes originales.

## regar/
- `regadera.png` (4 frames), `efectos_riego.png` (lluvia x4 + ondas x4), `tierra_mojada.png` (humeda / empapada / encharcada), `burbujas.png` (sed / perfecto / ahogada).
- `medidor_*.png`: marco, agua (nine-patch), brillo, zona verde y roja (nine-patch), flecha.
- `brote_1280.png`: brote suelto (47x39). Usar `fondos/fondo_vacio.png` + este brote en cada hueco, NO `fondo_brotes.png`.
- `riego_layout.json`: rectangulos de cada frame, anclas y datos del medidor.
- Orden de capas: fondo vacio, tierra mojada, brote, burbuja, ondas, lluvia, regadera.
- `build_riego.py`, `extract_brotes.py`: scripts generadores.

## quitar_plantas/  (PENDIENTE)
Falta: planta grande suelta (transparente), planta arrancada con raiz y 3-4 niveles de tierra, particulas de tierra, canasta, icono de papa cosechada.

## composta/  (PENDIENTE)
Falta: fondo del contenedor, ingredientes (3-4), mezcla en 4-5 etapas, palita, composta aplicada en cada cama.

## Descartado
Los sprites de siembra de la primera version (vista de una sola cama, 10 huecos) ya no sirven: el juego usa 24 huecos en vista cenital.
