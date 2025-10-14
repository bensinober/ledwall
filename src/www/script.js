const canvasContainer = document.getElementById("canvas-container")
const imageUpload = document.getElementById("imageUpload");
let width, height

let pixels = []; // Stores the color of each pixel
let isDrawing = false
let activeWall = false

function setGrid(h, w) {
  width = w
  height = h
}

// Initialize the pixel grid
function createGrid() {
  const rows = height
  const cols = width
  canvasContainer.innerHTML = ""; // Clear previous grid
  canvasContainer.style.gridTemplateColumns = `repeat(${cols}, 1fr)`
  canvasContainer.style.gridTemplateRows = `repeat(${rows}, 1fr)`
  pixels = []

  for (let i = 0; i < rows * cols; i++) {
    const pixel = document.createElement("div")
    pixel.classList.add("pixel")
    pixel.dataset.index = i
    pixel.style.backgroundColor = "#000000" // Default white
    pixel.addEventListener("mousedown", startDrawing)
    pixel.addEventListener("mouseover", draw)
    pixel.addEventListener("touchstart", touchStart)
    pixel.addEventListener("touchMove", touchMove)
    canvasContainer.appendChild(pixel)
    pixels.push("#000000") // Store default color
  }
}

function startDrawing(event) {
  isDrawing = true
  draw(event)
}

function draw(event) {
  if (!isDrawing) { return }
  if (event.target.classList.contains("pixel")) {
    event.target.style.backgroundColor = colorPicker.value
    pixels[event.target.dataset.index] = colorPicker.value
  }
}

function stopDrawing() {
  isDrawing = false
}
// for touch
function touchStart(event) { draw(event.touches[0]) }
function touchMove(event) { draw(event.touches[0]); event.preventDefault(); }
function touchEnd(event) { stopDrawing(event.changedTouches[0]) }

// process image and transform to matrix
async function processImage(img) {
  try {
    console.log(`Image loaded: ${img}`);
    const tempCanvas = document.createElement("canvas")
    const ctx = tempCanvas.getContext("2d")

    // Scale image to fit grid size
    let targetWidth = width
    let targetHeight = height

    tempCanvas.width = targetWidth
    tempCanvas.height = targetHeight

    ctx.drawImage(img, 0, 0, img.width, img.height, 0, 0, targetWidth, targetHeight)

    const imageData = ctx.getImageData(0, 0, targetWidth, targetHeight).data

    // Recreate grid based on image dimensions
    createGrid(Math.round(targetHeight), Math.round(targetWidth))

    for (let i = 0; i < imageData.length; i += 4) {
      const r = imageData[i];
      const g = imageData[i + 1]
      const b = imageData[i + 2]
      const hexColor = `#${r.toString(16).padStart(2, "0")}${g.toString(16).padStart(2, "0")}${b.toString(16).padStart(2, "0")}`
      const pixelIndex = i / 4
      const pixelElement = canvasContainer.children[pixelIndex]
      if (pixelElement) {
        pixelElement.style.backgroundColor = hexColor
        pixels[pixelIndex] = hexColor
      }
    }
    // Perform image manipulation, e.g., draw on canvas, resize
    console.log(`Image loaded: ${img.width}x${img.height}`)
  } catch (error) {
    console.error(`Error loading image ${url}:`, error);
  }
}

function fileToPromise(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = (e) => resolve(e.target.result)
    reader.onerror = (e) => reject(e) // Handle potential errors
    reader.readAsDataURL(file)
  })
}

function imgToPromise(imgSrc) {
  return new Promise((resolve, reject) => {
    const img = new Image()
    img.onload = () => resolve(img)
    img.onerror = (error) => reject(error)
    img.src = imgSrc
  })
}

// Image upload and pixel loading
async function loadPixels(evt) {
  const files = imageUpload.files
  if (files.length <= 0) {
    alert("Please select an image to upload.")
    return
  }
  try {
    const filePromises = Array.from(files).map(file => fileToPromise(file))
    console.log(filePromises)
    const loadedFiles = await Promise.all(filePromises)
    for (const url of loadedFiles) {
      const img = await imgToPromise(url)
      console.log(`loading image: ${img}`)
      processImage(img)
      await sendImageCanvas()
    }
  } catch (err) {
    console.log(`err promise load: ${err}`)
  }

  /*
    const reader = new FileReader()
      reader.onload = function (e) {
        const img = new Image()
        img.onload = function () {
          const tempCanvas = document.createElement("canvas")
          const ctx = tempCanvas.getContext("2d")

          // Scale image to fit grid size
          let targetWidth = width
          let targetHeight = height

          tempCanvas.width = targetWidth
          tempCanvas.height = targetHeight

          ctx.drawImage(img, 0, 0, img.width, img.height, 0, 0, targetWidth, targetHeight)

          const imageData = ctx.getImageData(0, 0, targetWidth, targetHeight).data

          // Recreate grid based on image dimensions
          createGrid(Math.round(targetHeight), Math.round(targetWidth))

          for (let i = 0; i < imageData.length; i += 4) {
            const r = imageData[i];
            const g = imageData[i + 1]
            const b = imageData[i + 2]
            const hexColor = `#${r.toString(16).padStart(2, "0")}${g.toString(16).padStart(2, "0")}${b.toString(16).padStart(2, "0")}`
            const pixelIndex = i / 4
            const pixelElement = canvasContainer.children[pixelIndex]
            if (pixelElement) {
              pixelElement.style.backgroundColor = hexColor
              pixels[pixelIndex] = hexColor
            }
          }
        }
        img.src = e.target.result
        sendImageCanvas()
      }
      reader.readAsDataURL(f)
  */
}

function u32ToRgb(u32Color) {
  u32Color >>>= 0

  const b = u32Color & 0xFF // Extract Blue component (last 8 bits)
  const g = (u32Color >>> 8) & 0xFF // Extract Green component (next 8 bits, shifted right by 8)
  const r = (u32Color >>> 16) & 0xFF // Extract Red component (next 8 bits, shifted right by 16)

  return `rgb(${r}, ${g}, ${b})`
}

function setPixel(x, y, col) {
  const idx = ((height - y - 1) * width) + x // get index
  const pixel = document.querySelector(`.pixel[data-index="${idx}"]`)
  pixel.style.backgroundColor = u32ToRgb(col)
}

async function sendImageCanvas() {
  console.log("sending image")
  const tempCanvas = document.createElement("canvas")
  tempCanvas.width = width
  tempCanvas.height = height
  const ctx = tempCanvas.getContext("2d")

  document.querySelectorAll(".pixel").forEach((pixel, index) => {
    const x = index % width
    const y = Math.floor(index / width)
    const color =
      pixel.style.backgroundColor === "rgb(238, 238, 238)"
        ? "#eee"
        : pixel.style.backgroundColor // Default to light gray if not explicitly colored
    ctx.fillStyle = color
    ctx.fillRect(x, y, 1, 1)
  })

  const bytes = getRawBytes(tempCanvas)
  await uploadRawPngBytes(bytes)
  console.log(bytes)
}

function getRawBytes(canvas) {
  const ctx = canvas.getContext("2d")
  const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height)
  const rgbaData = imageData.data // Uint8ClampedArray (R, G, B, A for each pixel) starting top left
  return rgbaData
}

async function uploadRawPngBytes(bytes) {
  try {
    const res = await fetch("/uploadRawImg", {
      method: "POST",
      headers: {
        "Content-Type": "image/png",
      },
      body: bytes, // Send the raw bytes directly
    })
    if (res.ok) {
      console.log("PNG uploaded successfully!")
    } else {
      console.error("Failed to upload PNG:", res.statusText)
    }
  } catch (err) {
    console.log(err)
  }
}

async function toggleActive() {
  try {
    const res = await fetch("/toggleActive", { method: "PUT" })
    if (res.ok) {
      console.log("Toggled successfully!")
      activeWall = !activeWall
      if (activeWall) {
        document.getElementById("toggleButton").classList.add("active")
        document.getElementById("toggleButton").innerText = "Stopp"
      } else {
        document.getElementById("toggleButton").classList.remove("active")
        document.getElementById("toggleButton").innerText = "Kjør"
      }
    } else {
      console.error("Failed to toggle active: ", res.statusText)
    }
  } catch (err) {
    console.log(err)
  }
}

async function frameDelay(e) {
  console.log(e)
  const delay = e.target.value
  try {
    const res = await fetch("/frameDelay", {
      method: "POST",
      headers: {
        "Content-Type": "text/plain",
      },
      body: delay,
    })
    if (res.ok) {
      console.log("OK")
    } else {
      console.error("Failed to set frame delay: ", res.statusText)
    }
  } catch (err) {
    console.log(err)
  }
}

async function start() {
  try {
    const res = await fetch("/start", { method: "PUT" })
    if (res.ok) {
      console.log("started successfully!")
    } else {
      console.error("Failed to start wall: ", res.statusText)
    }
  } catch (err) {
    console.log(err)
  }
}

function download(evt) {
  const tempCanvas = document.createElement("canvas")
  tempCanvas.width = width
  tempCanvas.height = height
  const ctx = tempCanvas.getContext("2d")

  document.querySelectorAll(".pixel").forEach((pixel, index) => {
    const x = index % width
    const y = Math.floor(index / width)
    const color =
      pixel.style.backgroundColor === "rgb(238, 238, 238)"
        ? "#eee"
        : pixel.style.backgroundColor // Default to light gray if not explicitly colored
    ctx.fillStyle = color
    ctx.fillRect(x, y, 1, 1)
  })

  const link = document.createElement("a")
  link.download = "pixel_art.png"
  link.href = tempCanvas.toDataURL("image/png")
  link.click()
}

let charIndexX = 23
let textAnimationInterval
let scrollText = ""

/*
async function textInput(e) {
  console.log(e)
  scrollText = e.target.value
  textAnimationInterval = setInterval(renderText, 100) // move every 100ms
  setTimeout(() => {
    clearInterval(textAnimationInterval)
  }, 10000)
}
*/

async function textInput(e) {
  console.log(e)
  const text = e.target.value
  const frameDelay = document.getElementById("frameDelay").value
  try {
    const res = await fetch("/setText", {
      method: "POST",
      headers: {
        "Content-Type": "text/plain",
      },
      body: JSON.stringify({ text: text, frameDelay: frameDelay }),
    })
    if (res.ok) {
      console.log("OK")
    } else {
      console.error("Failed to set text: ", res.statusText)
    }
  } catch (err) {
    console.log(err)
  }
}

// NOT USED
async function renderText() {
  if (charIndexX < 100) {
    await renderTextAtPos(scrollText)
    charIndexX--
  } else {
    clearInterval(textAnimationInterval) // Stop the animation when done
  }
}

// NOT USED
async function renderTextAtPos(text) {
  try {
    const res = await fetch("/textScroll", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        text: text,
        x: charIndexX,
        y: 4,
        col: 255,
      })
    })
    if (res.ok) {
      const json = await res.json()
      console.log(json)
      for (const char of json.items) {
        var trailingRow
        for (const pixel of char.pixels.items) {
          if (pixel.x >= 0 && pixel.x < 24) {
            setPixel(pixel.x, pixel.y, pixel.col)
          }
          trailingRow = pixel.x + 1 // to clear col after before shifting left
        }
        for (var y = 4; y < 12; y++) {
          if (trailingRow > 0 && trailingRow < 24) {
            setPixel(trailingRow, y, 0xffffff)
          }
        }

      }
    } else {
      console.error("Failed to send text: ", res.statusText)
    }
  } catch (err) {
    console.log(err)
  }
}

function clearCanvas() {
  createGrid() // Re-initialize with default white pixels
}

async function clearMat() {
  try {
    const res = await fetch("/clearMat", { method: "PUT" })
    if (!res.ok) {
      console.log(res.statusText)
    }
  } catch (err) {
    console.log(err)
  }
}

function leftBtn() {
  return fetch("/left")
}
function upBtn() {
  return fetch("/up")
}
function rightBtn() {
  return fetch("/right")
}
function downBtn() {
  return fetch("/down")
}
function gameStartBtn() {
  return fetch("/gameStart")
}

// Event listeners for drawing
document.addEventListener("mouseup", stopDrawing)
canvasContainer.addEventListener("mouseleave", stopDrawing)
canvasContainer.addEventListener('touchend', touchEnd, false)



export {
  setGrid, createGrid, loadPixels, textInput, clearCanvas, clearMat, download, sendImageCanvas, toggleActive, start, frameDelay,
  leftBtn, rightBtn, upBtn, downBtn, gameStartBtn,
}
