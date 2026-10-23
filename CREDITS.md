# Créditos y licencias de terceros

faro está escrito desde cero. **No contiene código de ninguno de los proyectos mencionados aquí**; algunos fueron fuente de inspiración y otros son servicios o herramientas que la app usa.

## Inspiración

| Proyecto | Qué inspiró |
|---|---|
| **Irvue** | Los fondos de pantalla por canales y temas. |
| **Sapphire** ([cshariq/Sapphire](https://github.com/cshariq/Sapphire), AGPL-3.0) | La idea de aprovechar el notch como espacio útil. faro no reutiliza su código. |
| **CopyClip** | La idea del historial del portapapeles. |

Los nombres pertenecen a sus respectivos dueños. faro no tiene relación con ellos.

## Servicios de datos

| Servicio | Uso | Condiciones |
|---|---|---|
| [Wallhaven](https://wallhaven.cc) | Fotos de fondo | API pública sin clave; solo se piden resultados de contenido seguro. Cada imagen tiene su propia licencia. |
| [Wikimedia Commons](https://commons.wikimedia.org) | Fotos destacadas | Cada archivo tiene su licencia (a menudo CC BY o CC BY-SA, con atribución); faro muestra el autor junto a la imagen. |
| [Bing](https://www.bing.com) | Imagen del día | Imágenes de uso personal como fondo; pertenecen a Microsoft y a sus fotógrafos. |
| [Open-Meteo](https://open-meteo.com) | Clima y geocodificación | Datos meteorológicos de [Open-Meteo.com](https://open-meteo.com/), bajo licencia [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Su uso gratuito es para fines no comerciales. |
| Servidores de Apple (`networkQuality`) | Medición de internet | Herramienta incluida en macOS. |

## Tecnologías

- **Swift**, **SwiftUI**, **AppKit**, **EventKit**, **Charts**, **CryptoKit**, **ImageIO** y **IOKit**, de Apple.
- **Símbolos SF** de Apple para los íconos de las funciones. El símbolo del faro, y los signos de más, equis, flecha y palomita de la interfaz, están dibujados a mano para este proyecto.
- El código de conducta se inspira en el [Contributor Covenant](https://www.contributor-covenant.org) 2.1 (CC BY 4.0).

## Dependencias

faro **no usa dependencias externas** de código: solo los frameworks del sistema.
