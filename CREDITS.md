# Servicios y licencias de terceros

faro está escrito desde cero y no usa dependencias externas de código. Este documento registra los servicios de datos y las tecnologías del sistema que hacen posible algunas funciones.

## Servicios de datos

| Servicio | Uso | Condiciones |
|---|---|---|
| [Wallhaven](https://wallhaven.cc) | Fotos de fondo | API pública sin clave; solo se piden resultados de contenido seguro. Cada imagen tiene su propia licencia. |
| [Wikimedia Commons](https://commons.wikimedia.org) | Fotos destacadas | Cada archivo tiene su licencia (a menudo CC BY o CC BY-SA, con atribución); faro muestra el autor junto a la imagen. |
| [Art Institute of Chicago](https://api.artic.edu/docs/) | Obras de dominio público | Se piden solo obras marcadas como dominio público y se identifica la app con la cabecera `AIC-User-Agent`, como pide su política de uso. |
| [NASA Image and Video Library](https://images.nasa.gov) | Imágenes del espacio | Las imágenes de la NASA no tienen derechos de autor en general; revisa el aviso de cada una si las reutilizas. |
| [Picsum](https://picsum.photos) | Fotos al azar | Fotos de [Unsplash](https://unsplash.com), con el autor en la ficha de cada foto. |
| [Bing](https://www.bing.com) | Imagen del día | Imágenes de uso personal como fondo; pertenecen a Microsoft y a sus fotógrafos. |
| [LRCLIB](https://lrclib.net) | Letras sincronizadas | Servicio gratuito y abierto; cada letra pertenece a sus autores y se muestra solo para acompañar lo que suena. |
| [Open-Meteo](https://open-meteo.com) | Clima y geocodificación | Datos meteorológicos de [Open-Meteo.com](https://open-meteo.com/), bajo licencia [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Su uso gratuito es para fines no comerciales. |
| Servidores de Apple (`networkQuality`) | Medición de internet | Herramienta incluida en macOS. |

## Tecnologías

- **Swift**, **SwiftUI**, **AppKit**, **EventKit**, **Charts**, **CryptoKit**, **ImageIO** y **IOKit**, de Apple.
- **Símbolos SF** de Apple para los íconos de las funciones. El logo del faro (`docs/images/logo.svg`), y los signos de más, equis, flecha y palomita de la interfaz, están dibujados a mano para este proyecto.
- El código de conducta adapta el [Contributor Covenant](https://www.contributor-covenant.org) 2.1 (CC BY 4.0).

## Dependencias

faro **no usa dependencias externas** de código: solo los frameworks del sistema.
