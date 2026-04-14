// Compiles a dart2wasm-generated main module from `source` which can then
// instantiatable via the `instantiate` method.
//
// `source` needs to be a `Response` object (or promise thereof) e.g. created
// via the `fetch()` JS API.
export async function compileStreaming(source) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(
      await WebAssembly.compileStreaming(source, builtins), builtins);
}

// Compiles a dart2wasm-generated wasm modules from `bytes` which is then
// instantiatable via the `instantiate` method.
export async function compile(bytes) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(await WebAssembly.compile(bytes, builtins), builtins);
}

// DEPRECATED: Please use `compile` or `compileStreaming` to get a compiled app,
// use `instantiate` method to get an instantiated app and then call
// `invokeMain` to invoke the main function.
export async function instantiate(modulePromise, importObjectPromise) {
  var moduleOrCompiledApp = await modulePromise;
  if (!(moduleOrCompiledApp instanceof CompiledApp)) {
    moduleOrCompiledApp = new CompiledApp(moduleOrCompiledApp);
  }
  const instantiatedApp = await moduleOrCompiledApp.instantiate(await importObjectPromise);
  return instantiatedApp.instantiatedModule;
}

// DEPRECATED: Please use `compile` or `compileStreaming` to get a compiled app,
// use `instantiate` method to get an instantiated app and then call
// `invokeMain` to invoke the main function.
export const invoke = (moduleInstance, ...args) => {
  moduleInstance.exports.$invokeMain(args);
}

class CompiledApp {
  constructor(module, builtins) {
    this.module = module;
    this.builtins = builtins;
  }

  // The second argument is an options object containing:
  // `loadDeferredWasm` is a JS function that takes a module name matching a
  //   wasm file produced by the dart2wasm compiler and returns the bytes to
  //   load the module. These bytes can be in either a format supported by
  //   `WebAssembly.compile` or `WebAssembly.compileStreaming`.
  // `loadDynamicModule` is a JS function that takes two string names matching,
  //   in order, a wasm file produced by the dart2wasm compiler during dynamic
  //   module compilation and a corresponding js file produced by the same
  //   compilation. It should return a JS Array containing 2 elements. The first
  //   should be the bytes for the wasm module in a format supported by
  //   `WebAssembly.compile` or `WebAssembly.compileStreaming`. The second
  //   should be the result of using the JS 'import' API on the js file path.
  async instantiate(additionalImports, {loadDeferredWasm, loadDynamicModule} = {}) {
    let dartInstance;

    // Prints to the console
    function printToConsole(value) {
      if (typeof dartPrint == "function") {
        dartPrint(value);
        return;
      }
      if (typeof console == "object" && typeof console.log != "undefined") {
        console.log(value);
        return;
      }
      if (typeof print == "function") {
        print(value);
        return;
      }

      throw "Unable to print message: " + value;
    }

    // A special symbol attached to functions that wrap Dart functions.
    const jsWrappedDartFunctionSymbol = Symbol("JSWrappedDartFunction");

    function finalizeWrapper(dartFunction, wrapped) {
      wrapped.dartFunction = dartFunction;
      wrapped[jsWrappedDartFunctionSymbol] = true;
      return wrapped;
    }

    // Imports
    const dart2wasm = {
            _3: (o, t) => typeof o === t,
      _4: (o, c) => o instanceof c,
      _7: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._7(f,arguments.length,x0) }),
      _8: f => finalizeWrapper(f, function(x0,x1) { return dartInstance.exports._8(f,arguments.length,x0,x1) }),
      _36: () => new Array(),
      _37: x0 => new Array(x0),
      _39: x0 => x0.length,
      _41: (x0,x1) => x0[x1],
      _42: (x0,x1,x2) => { x0[x1] = x2 },
      _44: x0 => new Promise(x0),
      _46: (x0,x1,x2) => new DataView(x0,x1,x2),
      _48: x0 => new Int8Array(x0),
      _49: (x0,x1,x2) => new Uint8Array(x0,x1,x2),
      _50: x0 => new Uint8Array(x0),
      _52: x0 => new Uint8ClampedArray(x0),
      _54: x0 => new Int16Array(x0),
      _56: x0 => new Uint16Array(x0),
      _58: x0 => new Int32Array(x0),
      _60: x0 => new Uint32Array(x0),
      _62: x0 => new Float32Array(x0),
      _64: x0 => new Float64Array(x0),
      _66: (x0,x1,x2) => x0.call(x1,x2),
      _71: (decoder, codeUnits) => decoder.decode(codeUnits),
      _72: () => new TextDecoder("utf-8", {fatal: true}),
      _73: () => new TextDecoder("utf-8", {fatal: false}),
      _74: (s) => +s,
      _75: x0 => new Uint8Array(x0),
      _76: (x0,x1,x2) => x0.set(x1,x2),
      _77: (x0,x1) => x0.transferFromImageBitmap(x1),
      _79: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._79(f,arguments.length,x0) }),
      _80: x0 => new window.FinalizationRegistry(x0),
      _81: (x0,x1,x2,x3) => x0.register(x1,x2,x3),
      _82: (x0,x1) => x0.unregister(x1),
      _83: (x0,x1,x2) => x0.slice(x1,x2),
      _84: (x0,x1) => x0.decode(x1),
      _85: (x0,x1) => x0.segment(x1),
      _86: () => new TextDecoder(),
      _88: x0 => x0.click(),
      _89: x0 => x0.buffer,
      _90: x0 => x0.wasmMemory,
      _91: () => globalThis.window._flutter_skwasmInstance,
      _92: x0 => x0.rasterStartMilliseconds,
      _93: x0 => x0.rasterEndMilliseconds,
      _94: x0 => x0.imageBitmaps,
      _121: x0 => x0.remove(),
      _122: (x0,x1) => x0.append(x1),
      _123: (x0,x1,x2) => x0.insertBefore(x1,x2),
      _124: (x0,x1) => x0.querySelector(x1),
      _126: (x0,x1) => x0.removeChild(x1),
      _204: x0 => x0.stopPropagation(),
      _205: x0 => x0.preventDefault(),
      _207: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      _252: x0 => x0.unlock(),
      _253: x0 => x0.getReader(),
      _254: (x0,x1,x2) => x0.addEventListener(x1,x2),
      _255: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      _256: (x0,x1) => x0.item(x1),
      _257: x0 => x0.next(),
      _258: x0 => x0.now(),
      _259: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._259(f,arguments.length,x0) }),
      _260: (x0,x1) => x0.addListener(x1),
      _261: (x0,x1) => x0.removeListener(x1),
      _262: (x0,x1) => x0.matchMedia(x1),
      _263: (x0,x1) => x0.revokeObjectURL(x1),
      _264: x0 => x0.close(),
      _265: (x0,x1,x2,x3,x4) => ({type: x0,data: x1,premultiplyAlpha: x2,colorSpaceConversion: x3,preferAnimation: x4}),
      _266: x0 => new window.ImageDecoder(x0),
      _267: x0 => ({frameIndex: x0}),
      _268: (x0,x1) => x0.decode(x1),
      _269: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._269(f,arguments.length,x0) }),
      _270: (x0,x1) => x0.getModifierState(x1),
      _271: (x0,x1) => x0.removeProperty(x1),
      _272: (x0,x1) => x0.prepend(x1),
      _273: x0 => new Intl.Locale(x0),
      _274: x0 => x0.disconnect(),
      _275: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._275(f,arguments.length,x0) }),
      _276: (x0,x1) => x0.getAttribute(x1),
      _277: (x0,x1) => x0.contains(x1),
      _278: x0 => x0.blur(),
      _279: x0 => x0.hasFocus(),
      _280: (x0,x1) => x0.hasAttribute(x1),
      _281: (x0,x1) => x0.getModifierState(x1),
      _282: (x0,x1) => x0.appendChild(x1),
      _283: (x0,x1) => x0.createTextNode(x1),
      _284: (x0,x1) => x0.removeAttribute(x1),
      _285: x0 => x0.getBoundingClientRect(),
      _286: (x0,x1) => x0.observe(x1),
      _287: x0 => x0.disconnect(),
      _288: (x0,x1) => x0.closest(x1),
      _710: () => globalThis.window.flutterConfiguration,
      _712: x0 => x0.assetBase,
      _718: x0 => x0.debugShowSemanticsNodes,
      _719: x0 => x0.hostElement,
      _720: x0 => x0.multiViewEnabled,
      _721: x0 => x0.nonce,
      _723: x0 => x0.fontFallbackBaseUrl,
      _733: x0 => x0.console,
      _734: x0 => x0.devicePixelRatio,
      _735: x0 => x0.document,
      _736: x0 => x0.history,
      _737: x0 => x0.innerHeight,
      _738: x0 => x0.innerWidth,
      _739: x0 => x0.location,
      _740: x0 => x0.navigator,
      _741: x0 => x0.visualViewport,
      _742: x0 => x0.performance,
      _744: x0 => x0.URL,
      _746: (x0,x1) => x0.getComputedStyle(x1),
      _747: x0 => x0.screen,
      _748: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._748(f,arguments.length,x0) }),
      _749: (x0,x1) => x0.requestAnimationFrame(x1),
      _754: (x0,x1) => x0.warn(x1),
      _756: (x0,x1) => x0.debug(x1),
      _757: x0 => globalThis.parseFloat(x0),
      _758: () => globalThis.window,
      _759: () => globalThis.Intl,
      _760: () => globalThis.Symbol,
      _761: (x0,x1,x2,x3,x4) => globalThis.createImageBitmap(x0,x1,x2,x3,x4),
      _763: x0 => x0.clipboard,
      _764: x0 => x0.maxTouchPoints,
      _765: x0 => x0.vendor,
      _766: x0 => x0.language,
      _767: x0 => x0.platform,
      _768: x0 => x0.userAgent,
      _769: (x0,x1) => x0.vibrate(x1),
      _770: x0 => x0.languages,
      _771: x0 => x0.documentElement,
      _772: (x0,x1) => x0.querySelector(x1),
      _775: (x0,x1) => x0.createElement(x1),
      _778: (x0,x1) => x0.createEvent(x1),
      _779: x0 => x0.activeElement,
      _782: x0 => x0.head,
      _783: x0 => x0.body,
      _784: (x0,x1) => { x0.title = x1 },
      _788: x0 => x0.visibilityState,
      _789: () => globalThis.document,
      _790: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._790(f,arguments.length,x0) }),
      _791: (x0,x1) => x0.dispatchEvent(x1),
      _799: x0 => x0.target,
      _801: x0 => x0.timeStamp,
      _802: x0 => x0.type,
      _804: (x0,x1,x2,x3) => x0.initEvent(x1,x2,x3),
      _810: x0 => x0.baseURI,
      _811: x0 => x0.firstChild,
      _815: x0 => x0.parentElement,
      _817: (x0,x1) => { x0.textContent = x1 },
      _818: x0 => x0.parentNode,
      _820: x0 => x0.isConnected,
      _824: x0 => x0.firstElementChild,
      _826: x0 => x0.nextElementSibling,
      _827: x0 => x0.clientHeight,
      _828: x0 => x0.clientWidth,
      _829: x0 => x0.offsetHeight,
      _830: x0 => x0.offsetWidth,
      _831: x0 => x0.id,
      _832: (x0,x1) => { x0.id = x1 },
      _835: (x0,x1) => { x0.spellcheck = x1 },
      _836: x0 => x0.tagName,
      _837: x0 => x0.style,
      _839: (x0,x1) => x0.querySelectorAll(x1),
      _840: (x0,x1,x2) => x0.setAttribute(x1,x2),
      _841: x0 => x0.tabIndex,
      _842: (x0,x1) => { x0.tabIndex = x1 },
      _843: (x0,x1) => x0.focus(x1),
      _844: x0 => x0.scrollTop,
      _845: (x0,x1) => { x0.scrollTop = x1 },
      _846: x0 => x0.scrollLeft,
      _847: (x0,x1) => { x0.scrollLeft = x1 },
      _848: x0 => x0.classList,
      _850: (x0,x1) => { x0.className = x1 },
      _852: (x0,x1) => x0.getElementsByClassName(x1),
      _853: (x0,x1) => x0.attachShadow(x1),
      _856: x0 => x0.computedStyleMap(),
      _857: (x0,x1) => x0.get(x1),
      _863: (x0,x1) => x0.getPropertyValue(x1),
      _864: (x0,x1,x2,x3) => x0.setProperty(x1,x2,x3),
      _865: x0 => x0.offsetLeft,
      _866: x0 => x0.offsetTop,
      _867: x0 => x0.offsetParent,
      _869: (x0,x1) => { x0.name = x1 },
      _870: x0 => x0.content,
      _871: (x0,x1) => { x0.content = x1 },
      _875: (x0,x1) => { x0.src = x1 },
      _876: x0 => x0.naturalWidth,
      _877: x0 => x0.naturalHeight,
      _881: (x0,x1) => { x0.crossOrigin = x1 },
      _883: (x0,x1) => { x0.decoding = x1 },
      _884: x0 => x0.decode(),
      _889: (x0,x1) => { x0.nonce = x1 },
      _894: (x0,x1) => { x0.width = x1 },
      _896: (x0,x1) => { x0.height = x1 },
      _899: (x0,x1) => x0.getContext(x1),
      _963: (x0,x1) => x0.fetch(x1),
      _964: x0 => x0.status,
      _966: x0 => x0.body,
      _967: x0 => x0.arrayBuffer(),
      _970: x0 => x0.read(),
      _971: x0 => x0.value,
      _972: x0 => x0.done,
      _979: x0 => x0.name,
      _980: x0 => x0.x,
      _981: x0 => x0.y,
      _984: x0 => x0.top,
      _985: x0 => x0.right,
      _986: x0 => x0.bottom,
      _987: x0 => x0.left,
      _999: x0 => x0.height,
      _1000: x0 => x0.width,
      _1001: x0 => x0.scale,
      _1002: (x0,x1) => { x0.value = x1 },
      _1005: (x0,x1) => { x0.placeholder = x1 },
      _1007: (x0,x1) => { x0.name = x1 },
      _1008: x0 => x0.selectionDirection,
      _1009: x0 => x0.selectionStart,
      _1010: x0 => x0.selectionEnd,
      _1013: x0 => x0.value,
      _1015: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      _1016: x0 => x0.readText(),
      _1017: (x0,x1) => x0.writeText(x1),
      _1019: x0 => x0.altKey,
      _1020: x0 => x0.code,
      _1021: x0 => x0.ctrlKey,
      _1022: x0 => x0.key,
      _1023: x0 => x0.keyCode,
      _1024: x0 => x0.location,
      _1025: x0 => x0.metaKey,
      _1026: x0 => x0.repeat,
      _1027: x0 => x0.shiftKey,
      _1028: x0 => x0.isComposing,
      _1030: x0 => x0.state,
      _1031: (x0,x1) => x0.go(x1),
      _1033: (x0,x1,x2,x3) => x0.pushState(x1,x2,x3),
      _1034: (x0,x1,x2,x3) => x0.replaceState(x1,x2,x3),
      _1035: x0 => x0.pathname,
      _1036: x0 => x0.search,
      _1037: x0 => x0.hash,
      _1041: x0 => x0.state,
      _1044: (x0,x1) => x0.createObjectURL(x1),
      _1046: x0 => new Blob(x0),
      _1048: x0 => new MutationObserver(x0),
      _1049: (x0,x1,x2) => x0.observe(x1,x2),
      _1050: f => finalizeWrapper(f, function(x0,x1) { return dartInstance.exports._1050(f,arguments.length,x0,x1) }),
      _1053: x0 => x0.attributeName,
      _1054: x0 => x0.type,
      _1055: x0 => x0.matches,
      _1056: x0 => x0.matches,
      _1060: x0 => x0.relatedTarget,
      _1062: x0 => x0.clientX,
      _1063: x0 => x0.clientY,
      _1064: x0 => x0.offsetX,
      _1065: x0 => x0.offsetY,
      _1068: x0 => x0.button,
      _1069: x0 => x0.buttons,
      _1070: x0 => x0.ctrlKey,
      _1074: x0 => x0.pointerId,
      _1075: x0 => x0.pointerType,
      _1076: x0 => x0.pressure,
      _1077: x0 => x0.tiltX,
      _1078: x0 => x0.tiltY,
      _1079: x0 => x0.getCoalescedEvents(),
      _1082: x0 => x0.deltaX,
      _1083: x0 => x0.deltaY,
      _1084: x0 => x0.wheelDeltaX,
      _1085: x0 => x0.wheelDeltaY,
      _1086: x0 => x0.deltaMode,
      _1093: x0 => x0.changedTouches,
      _1096: x0 => x0.clientX,
      _1097: x0 => x0.clientY,
      _1100: x0 => x0.data,
      _1103: (x0,x1) => { x0.disabled = x1 },
      _1105: (x0,x1) => { x0.type = x1 },
      _1106: (x0,x1) => { x0.max = x1 },
      _1107: (x0,x1) => { x0.min = x1 },
      _1108: x0 => x0.value,
      _1109: (x0,x1) => { x0.value = x1 },
      _1110: x0 => x0.disabled,
      _1111: (x0,x1) => { x0.disabled = x1 },
      _1113: (x0,x1) => { x0.placeholder = x1 },
      _1115: (x0,x1) => { x0.name = x1 },
      _1117: (x0,x1) => { x0.autocomplete = x1 },
      _1118: x0 => x0.selectionDirection,
      _1119: x0 => x0.selectionStart,
      _1122: x0 => x0.selectionEnd,
      _1124: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      _1125: (x0,x1) => x0.add(x1),
      _1128: (x0,x1) => { x0.noValidate = x1 },
      _1129: (x0,x1) => { x0.method = x1 },
      _1130: (x0,x1) => { x0.action = x1 },
      _1156: x0 => x0.orientation,
      _1157: x0 => x0.width,
      _1158: x0 => x0.height,
      _1159: (x0,x1) => x0.lock(x1),
      _1178: x0 => new ResizeObserver(x0),
      _1181: f => finalizeWrapper(f, function(x0,x1) { return dartInstance.exports._1181(f,arguments.length,x0,x1) }),
      _1189: x0 => x0.length,
      _1190: x0 => x0.iterator,
      _1191: x0 => x0.Segmenter,
      _1192: x0 => x0.v8BreakIterator,
      _1193: (x0,x1) => new Intl.Segmenter(x0,x1),
      _1195: x0 => x0.language,
      _1196: x0 => x0.script,
      _1197: x0 => x0.region,
      _1215: x0 => x0.done,
      _1216: x0 => x0.value,
      _1217: x0 => x0.index,
      _1221: (x0,x1) => new Intl.v8BreakIterator(x0,x1),
      _1222: (x0,x1) => x0.adoptText(x1),
      _1223: x0 => x0.first(),
      _1224: x0 => x0.next(),
      _1225: x0 => x0.current(),
      _1239: x0 => x0.hostElement,
      _1240: x0 => x0.viewConstraints,
      _1243: x0 => x0.maxHeight,
      _1244: x0 => x0.maxWidth,
      _1245: x0 => x0.minHeight,
      _1246: x0 => x0.minWidth,
      _1247: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1247(f,arguments.length,x0) }),
      _1248: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1248(f,arguments.length,x0) }),
      _1249: (x0,x1) => ({addView: x0,removeView: x1}),
      _1252: x0 => x0.loader,
      _1253: () => globalThis._flutter,
      _1254: (x0,x1) => x0.didCreateEngineInitializer(x1),
      _1255: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1255(f,arguments.length,x0) }),
      _1256: f => finalizeWrapper(f, function() { return dartInstance.exports._1256(f,arguments.length) }),
      _1257: (x0,x1) => ({initializeEngine: x0,autoStart: x1}),
      _1260: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1260(f,arguments.length,x0) }),
      _1261: x0 => ({runApp: x0}),
      _1263: f => finalizeWrapper(f, function(x0,x1) { return dartInstance.exports._1263(f,arguments.length,x0,x1) }),
      _1264: x0 => x0.length,
      _1265: () => globalThis.window.ImageDecoder,
      _1266: x0 => x0.tracks,
      _1268: x0 => x0.completed,
      _1270: x0 => x0.image,
      _1276: x0 => x0.displayWidth,
      _1277: x0 => x0.displayHeight,
      _1278: x0 => x0.duration,
      _1281: x0 => x0.ready,
      _1282: x0 => x0.selectedTrack,
      _1283: x0 => x0.repetitionCount,
      _1284: x0 => x0.frameCount,
      _1327: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1327(f,arguments.length,x0) }),
      _1328: (x0,x1,x2) => x0.addEventListener(x1,x2),
      _1329: (x0,x1,x2) => x0.postMessage(x1,x2),
      _1330: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      _1331: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1331(f,arguments.length,x0) }),
      _1332: () => globalThis.initializeGA(),
      _1334: (x0,x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14,x15,x16,x17,x18,x19,x20,x21,x22,x23,x24,x25,x26,x27,x28,x29,x30,x31,x32,x33) => ({screen: x0,event_category: x1,event_label: x2,send_to: x3,value: x4,non_interaction: x5,user_app: x6,user_build: x7,user_platform: x8,devtools_platform: x9,devtools_chrome: x10,devtools_version: x11,ide_launched: x12,flutter_client_id: x13,is_external_build: x14,is_embedded: x15,g3_username: x16,ide_launched_feature: x17,is_wasm: x18,ui_duration_micros: x19,raster_duration_micros: x20,shader_compilation_duration_micros: x21,cpu_sample_count: x22,cpu_stack_depth: x23,trace_event_count: x24,heap_diff_objects_before: x25,heap_diff_objects_after: x26,heap_objects_total: x27,root_set_count: x28,row_count: x29,inspector_tree_controller_id: x30,android_app_id: x31,ios_bundle_id: x32,is_v2_inspector: x33}),
      _1335: x0 => x0.screen,
      _1336: x0 => x0.user_app,
      _1337: x0 => x0.user_build,
      _1338: x0 => x0.user_platform,
      _1339: x0 => x0.devtools_platform,
      _1340: x0 => x0.devtools_chrome,
      _1341: x0 => x0.devtools_version,
      _1342: x0 => x0.ide_launched,
      _1344: x0 => x0.is_external_build,
      _1345: x0 => x0.is_embedded,
      _1346: x0 => x0.g3_username,
      _1347: x0 => x0.ide_launched_feature,
      _1348: x0 => x0.is_wasm,
      _1349: x0 => x0.ui_duration_micros,
      _1350: x0 => x0.raster_duration_micros,
      _1351: x0 => x0.shader_compilation_duration_micros,
      _1352: x0 => x0.cpu_sample_count,
      _1353: x0 => x0.cpu_stack_depth,
      _1354: x0 => x0.trace_event_count,
      _1355: x0 => x0.heap_diff_objects_before,
      _1356: x0 => x0.heap_diff_objects_after,
      _1357: x0 => x0.heap_objects_total,
      _1358: x0 => x0.root_set_count,
      _1359: x0 => x0.row_count,
      _1360: x0 => x0.inspector_tree_controller_id,
      _1361: x0 => x0.android_app_id,
      _1362: x0 => x0.ios_bundle_id,
      _1363: x0 => x0.is_v2_inspector,
      _1365: (x0,x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14,x15,x16,x17,x18,x19,x20,x21,x22,x23,x24,x25,x26,x27,x28,x29) => ({description: x0,fatal: x1,user_app: x2,user_build: x3,user_platform: x4,devtools_platform: x5,devtools_chrome: x6,devtools_version: x7,ide_launched: x8,flutter_client_id: x9,is_external_build: x10,is_embedded: x11,g3_username: x12,ide_launched_feature: x13,is_wasm: x14,ui_duration_micros: x15,raster_duration_micros: x16,shader_compilation_duration_micros: x17,cpu_sample_count: x18,cpu_stack_depth: x19,trace_event_count: x20,heap_diff_objects_before: x21,heap_diff_objects_after: x22,heap_objects_total: x23,root_set_count: x24,row_count: x25,inspector_tree_controller_id: x26,android_app_id: x27,ios_bundle_id: x28,is_v2_inspector: x29}),
      _1366: x0 => x0.user_app,
      _1367: x0 => x0.user_build,
      _1368: x0 => x0.user_platform,
      _1369: x0 => x0.devtools_platform,
      _1370: x0 => x0.devtools_chrome,
      _1371: x0 => x0.devtools_version,
      _1372: x0 => x0.ide_launched,
      _1374: x0 => x0.is_external_build,
      _1375: x0 => x0.is_embedded,
      _1376: x0 => x0.g3_username,
      _1377: x0 => x0.ide_launched_feature,
      _1378: x0 => x0.is_wasm,
      _1394: () => globalThis.getDevToolsPropertyID(),
      _1395: () => globalThis.hookupListenerForGA(),
      _1396: (x0,x1,x2) => globalThis.gtag(x0,x1,x2),
      _1398: x0 => x0.event_category,
      _1399: x0 => x0.event_label,
      _1401: x0 => x0.value,
      _1402: x0 => x0.non_interaction,
      _1405: x0 => x0.description,
      _1406: x0 => x0.fatal,
      _1407: (x0,x1) => x0.getItem(x1),
      _1408: (x0,x1,x2) => x0.setItem(x1,x2),
      _1409: (x0,x1) => x0.querySelectorAll(x1),
      _1410: (x0,x1) => x0.removeChild(x1),
      _1411: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1411(f,arguments.length,x0) }),
      _1412: (x0,x1) => x0.forEach(x1),
      _1413: x0 => x0.preventDefault(),
      _1414: (x0,x1) => x0.execCommand(x1),
      _1415: (x0,x1) => x0.createElement(x1),
      _1416: x0 => new Blob(x0),
      _1417: x0 => globalThis.URL.createObjectURL(x0),
      _1418: (x0,x1,x2) => x0.setAttribute(x1,x2),
      _1419: (x0,x1) => x0.append(x1),
      _1420: x0 => x0.click(),
      _1421: x0 => x0.remove(),
      _1422: (x0,x1) => x0.item(x1),
      _1423: () => new FileReader(),
      _1424: (x0,x1) => x0.readAsText(x1),
      _1425: x0 => x0.createRange(),
      _1426: (x0,x1) => x0.selectNode(x1),
      _1427: x0 => x0.getSelection(),
      _1428: x0 => x0.removeAllRanges(),
      _1429: (x0,x1) => x0.addRange(x1),
      _1430: (x0,x1) => x0.createElement(x1),
      _1431: (x0,x1) => x0.append(x1),
      _1432: (x0,x1,x2) => x0.insertRule(x1,x2),
      _1433: (x0,x1) => x0.add(x1),
      _1434: x0 => x0.preventDefault(),
      _1435: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1435(f,arguments.length,x0) }),
      _1436: (x0,x1,x2) => x0.addEventListener(x1,x2),
      _1437: () => globalThis.window.navigator.userAgent,
      _1438: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1438(f,arguments.length,x0) }),
      _1439: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      _1440: (x0,x1,x2,x3) => x0.removeEventListener(x1,x2,x3),
      _1445: (x0,x1) => x0.closest(x1),
      _1446: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      _1447: x0 => x0.decode(),
      _1448: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      _1449: (x0,x1,x2) => x0.setRequestHeader(x1,x2),
      _1450: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1450(f,arguments.length,x0) }),
      _1451: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1451(f,arguments.length,x0) }),
      _1452: x0 => x0.send(),
      _1453: () => new XMLHttpRequest(),
      _1454: (x0,x1) => x0.querySelector(x1),
      _1455: (x0,x1) => x0.appendChild(x1),
      _1456: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1456(f,arguments.length,x0) }),
      _1457: Date.now,
      _1459: s => new Date(s * 1000).getTimezoneOffset() * 60,
      _1460: s => {
        if (!/^\s*[+-]?(?:Infinity|NaN|(?:\.\d+|\d+(?:\.\d*)?)(?:[eE][+-]?\d+)?)\s*$/.test(s)) {
          return NaN;
        }
        return parseFloat(s);
      },
      _1461: () => {
        let stackString = new Error().stack.toString();
        let frames = stackString.split('\n');
        let drop = 2;
        if (frames[0] === 'Error') {
            drop += 1;
        }
        return frames.slice(drop).join('\n');
      },
      _1462: () => typeof dartUseDateNowForTicks !== "undefined",
      _1463: () => 1000 * performance.now(),
      _1464: () => Date.now(),
      _1465: () => {
        // On browsers return `globalThis.location.href`
        if (globalThis.location != null) {
          return globalThis.location.href;
        }
        return null;
      },
      _1466: () => {
        return typeof process != "undefined" &&
               Object.prototype.toString.call(process) == "[object process]" &&
               process.platform == "win32"
      },
      _1467: () => new WeakMap(),
      _1468: (map, o) => map.get(o),
      _1469: (map, o, v) => map.set(o, v),
      _1470: x0 => new WeakRef(x0),
      _1471: x0 => x0.deref(),
      _1478: () => globalThis.WeakRef,
      _1482: s => JSON.stringify(s),
      _1483: s => printToConsole(s),
      _1484: (o, p, r) => o.replaceAll(p, () => r),
      _1485: (o, p, r) => o.replace(p, () => r),
      _1486: Function.prototype.call.bind(String.prototype.toLowerCase),
      _1487: s => s.toUpperCase(),
      _1488: s => s.trim(),
      _1489: s => s.trimLeft(),
      _1490: s => s.trimRight(),
      _1491: (string, times) => string.repeat(times),
      _1492: Function.prototype.call.bind(String.prototype.indexOf),
      _1493: (s, p, i) => s.lastIndexOf(p, i),
      _1494: (string, token) => string.split(token),
      _1495: Object.is,
      _1496: o => o instanceof Array,
      _1497: (a, i) => a.push(i),
      _1498: (a, i) => a.splice(i, 1)[0],
      _1500: (a, l) => a.length = l,
      _1501: a => a.pop(),
      _1502: (a, i) => a.splice(i, 1),
      _1503: (a, s) => a.join(s),
      _1504: (a, s, e) => a.slice(s, e),
      _1505: (a, s, e) => a.splice(s, e),
      _1506: (a, b) => a == b ? 0 : (a > b ? 1 : -1),
      _1507: a => a.length,
      _1508: (a, l) => a.length = l,
      _1509: (a, i) => a[i],
      _1510: (a, i, v) => a[i] = v,
      _1512: o => {
        if (o instanceof ArrayBuffer) return 0;
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
          return 1;
        }
        return 2;
      },
      _1513: (o, offsetInBytes, lengthInBytes) => {
        var dst = new ArrayBuffer(lengthInBytes);
        new Uint8Array(dst).set(new Uint8Array(o, offsetInBytes, lengthInBytes));
        return new DataView(dst);
      },
      _1515: o => o instanceof Uint8Array,
      _1516: (o, start, length) => new Uint8Array(o.buffer, o.byteOffset + start, length),
      _1517: o => o instanceof Int8Array,
      _1518: (o, start, length) => new Int8Array(o.buffer, o.byteOffset + start, length),
      _1519: o => o instanceof Uint8ClampedArray,
      _1520: (o, start, length) => new Uint8ClampedArray(o.buffer, o.byteOffset + start, length),
      _1521: o => o instanceof Uint16Array,
      _1522: (o, start, length) => new Uint16Array(o.buffer, o.byteOffset + start, length),
      _1523: o => o instanceof Int16Array,
      _1524: (o, start, length) => new Int16Array(o.buffer, o.byteOffset + start, length),
      _1525: o => o instanceof Uint32Array,
      _1526: (o, start, length) => new Uint32Array(o.buffer, o.byteOffset + start, length),
      _1527: o => o instanceof Int32Array,
      _1528: (o, start, length) => new Int32Array(o.buffer, o.byteOffset + start, length),
      _1530: (o, start, length) => new BigInt64Array(o.buffer, o.byteOffset + start, length),
      _1531: o => o instanceof Float32Array,
      _1532: (o, start, length) => new Float32Array(o.buffer, o.byteOffset + start, length),
      _1533: o => o instanceof Float64Array,
      _1534: (o, start, length) => new Float64Array(o.buffer, o.byteOffset + start, length),
      _1535: (t, s) => t.set(s),
      _1537: (o) => new DataView(o.buffer, o.byteOffset, o.byteLength),
      _1538: o => o.byteLength,
      _1539: o => o.buffer,
      _1540: o => o.byteOffset,
      _1541: Function.prototype.call.bind(Object.getOwnPropertyDescriptor(DataView.prototype, 'byteLength').get),
      _1542: (b, o) => new DataView(b, o),
      _1543: (b, o, l) => new DataView(b, o, l),
      _1544: Function.prototype.call.bind(DataView.prototype.getUint8),
      _1545: Function.prototype.call.bind(DataView.prototype.setUint8),
      _1546: Function.prototype.call.bind(DataView.prototype.getInt8),
      _1547: Function.prototype.call.bind(DataView.prototype.setInt8),
      _1548: Function.prototype.call.bind(DataView.prototype.getUint16),
      _1549: Function.prototype.call.bind(DataView.prototype.setUint16),
      _1550: Function.prototype.call.bind(DataView.prototype.getInt16),
      _1551: Function.prototype.call.bind(DataView.prototype.setInt16),
      _1552: Function.prototype.call.bind(DataView.prototype.getUint32),
      _1553: Function.prototype.call.bind(DataView.prototype.setUint32),
      _1554: Function.prototype.call.bind(DataView.prototype.getInt32),
      _1555: Function.prototype.call.bind(DataView.prototype.setInt32),
      _1558: Function.prototype.call.bind(DataView.prototype.getBigInt64),
      _1559: Function.prototype.call.bind(DataView.prototype.setBigInt64),
      _1560: Function.prototype.call.bind(DataView.prototype.getFloat32),
      _1561: Function.prototype.call.bind(DataView.prototype.setFloat32),
      _1562: Function.prototype.call.bind(DataView.prototype.getFloat64),
      _1563: Function.prototype.call.bind(DataView.prototype.setFloat64),
      _1576: (ms, c) =>
      setTimeout(() => dartInstance.exports.$invokeCallback(c),ms),
      _1577: (handle) => clearTimeout(handle),
      _1578: (ms, c) =>
      setInterval(() => dartInstance.exports.$invokeCallback(c), ms),
      _1579: (handle) => clearInterval(handle),
      _1580: (c) =>
      queueMicrotask(() => dartInstance.exports.$invokeCallback(c)),
      _1581: () => Date.now(),
      _1586: o => Object.keys(o),
      _1587: (x0,x1) => new WebSocket(x0,x1),
      _1588: (x0,x1) => x0.send(x1),
      _1589: (x0,x1,x2) => x0.close(x1,x2),
      _1591: x0 => x0.close(),
      _1592: () => new AbortController(),
      _1593: x0 => x0.abort(),
      _1594: (x0,x1,x2,x3,x4,x5) => ({method: x0,headers: x1,body: x2,credentials: x3,redirect: x4,signal: x5}),
      _1595: (x0,x1) => globalThis.fetch(x0,x1),
      _1596: (x0,x1) => x0.get(x1),
      _1597: f => finalizeWrapper(f, function(x0,x1,x2) { return dartInstance.exports._1597(f,arguments.length,x0,x1,x2) }),
      _1598: (x0,x1) => x0.forEach(x1),
      _1599: x0 => x0.getReader(),
      _1600: x0 => x0.read(),
      _1601: x0 => x0.cancel(),
      _1602: x0 => ({withCredentials: x0}),
      _1603: (x0,x1) => new EventSource(x0,x1),
      _1604: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1604(f,arguments.length,x0) }),
      _1605: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1605(f,arguments.length,x0) }),
      _1606: x0 => x0.close(),
      _1607: (x0,x1,x2) => ({method: x0,body: x1,credentials: x2}),
      _1608: (x0,x1,x2) => x0.fetch(x1,x2),
      _1611: () => new XMLHttpRequest(),
      _1612: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      _1613: x0 => x0.send(),
      _1615: (x0,x1) => x0.readAsArrayBuffer(x1),
      _1621: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1621(f,arguments.length,x0) }),
      _1622: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1622(f,arguments.length,x0) }),
      _1627: x0 => ({body: x0}),
      _1628: (x0,x1) => new Notification(x0,x1),
      _1629: () => globalThis.Notification.requestPermission(),
      _1630: x0 => x0.close(),
      _1631: x0 => x0.reload(),
      _1632: (x0,x1) => x0.groupCollapsed(x1),
      _1633: (x0,x1) => x0.log(x1),
      _1634: x0 => x0.groupEnd(),
      _1635: (x0,x1) => x0.warn(x1),
      _1636: (x0,x1) => x0.error(x1),
      _1637: x0 => x0.measureUserAgentSpecificMemory(),
      _1638: x0 => x0.bytes,
      _1648: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1648(f,arguments.length,x0) }),
      _1649: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1649(f,arguments.length,x0) }),
      _1650: x0 => x0.blur(),
      _1651: (x0,x1) => x0.replace(x1),
      _1652: (x0,x1,x2,x3) => x0.replaceState(x1,x2,x3),
      _1662: (s, m) => {
        try {
          return new RegExp(s, m);
        } catch (e) {
          return String(e);
        }
      },
      _1663: (x0,x1) => x0.exec(x1),
      _1664: (x0,x1) => x0.test(x1),
      _1665: x0 => x0.pop(),
      _1667: o => o === undefined,
      _1669: o => typeof o === 'function' && o[jsWrappedDartFunctionSymbol] === true,
      _1671: o => {
        const proto = Object.getPrototypeOf(o);
        return proto === Object.prototype || proto === null;
      },
      _1672: o => o instanceof RegExp,
      _1673: (l, r) => l === r,
      _1674: o => o,
      _1675: o => o,
      _1676: o => o,
      _1677: b => !!b,
      _1678: o => o.length,
      _1680: (o, i) => o[i],
      _1681: f => f.dartFunction,
      _1682: () => ({}),
      _1683: () => [],
      _1685: () => globalThis,
      _1686: (constructor, args) => {
        const factoryFunction = constructor.bind.apply(
            constructor, [null, ...args]);
        return new factoryFunction();
      },
      _1687: (o, p) => p in o,
      _1688: (o, p) => o[p],
      _1689: (o, p, v) => o[p] = v,
      _1690: (o, m, a) => o[m].apply(o, a),
      _1692: o => String(o),
      _1693: (p, s, f) => p.then(s, (e) => f(e, e === undefined)),
      _1694: o => {
        if (o === undefined) return 1;
        var type = typeof o;
        if (type === 'boolean') return 2;
        if (type === 'number') return 3;
        if (type === 'string') return 4;
        if (o instanceof Array) return 5;
        if (ArrayBuffer.isView(o)) {
          if (o instanceof Int8Array) return 6;
          if (o instanceof Uint8Array) return 7;
          if (o instanceof Uint8ClampedArray) return 8;
          if (o instanceof Int16Array) return 9;
          if (o instanceof Uint16Array) return 10;
          if (o instanceof Int32Array) return 11;
          if (o instanceof Uint32Array) return 12;
          if (o instanceof Float32Array) return 13;
          if (o instanceof Float64Array) return 14;
          if (o instanceof DataView) return 15;
        }
        if (o instanceof ArrayBuffer) return 16;
        // Feature check for `SharedArrayBuffer` before doing a type-check.
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
            return 17;
        }
        return 18;
      },
      _1695: o => [o],
      _1696: (o0, o1) => [o0, o1],
      _1697: (o0, o1, o2) => [o0, o1, o2],
      _1698: (o0, o1, o2, o3) => [o0, o1, o2, o3],
      _1699: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI8ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _1700: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI8ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _1701: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI16ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _1702: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI16ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _1703: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _1704: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _1705: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _1706: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _1707: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF64ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _1708: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF64ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _1709: x0 => new ArrayBuffer(x0),
      _1710: s => {
        if (/[[\]{}()*+?.\\^$|]/.test(s)) {
            s = s.replace(/[[\]{}()*+?.\\^$|]/g, '\\$&');
        }
        return s;
      },
      _1711: x0 => x0.input,
      _1712: x0 => x0.index,
      _1713: x0 => x0.groups,
      _1714: x0 => x0.flags,
      _1715: x0 => x0.multiline,
      _1716: x0 => x0.ignoreCase,
      _1717: x0 => x0.unicode,
      _1718: x0 => x0.dotAll,
      _1719: (x0,x1) => { x0.lastIndex = x1 },
      _1720: (o, p) => p in o,
      _1721: (o, p) => o[p],
      _1724: x0 => x0.random(),
      _1727: () => globalThis.Math,
      _1728: Function.prototype.call.bind(Number.prototype.toString),
      _1729: Function.prototype.call.bind(BigInt.prototype.toString),
      _1730: Function.prototype.call.bind(Number.prototype.toString),
      _1731: (d, digits) => d.toFixed(digits),
      _1734: (d, precision) => d.toPrecision(precision),
      _1735: () => globalThis.document,
      _1736: () => globalThis.window,
      _1741: (x0,x1) => { x0.height = x1 },
      _1743: (x0,x1) => { x0.width = x1 },
      _1746: x0 => x0.head,
      _1747: x0 => x0.classList,
      _1751: (x0,x1) => { x0.innerText = x1 },
      _1752: x0 => x0.style,
      _1754: x0 => x0.sheet,
      _1755: x0 => x0.src,
      _1756: (x0,x1) => { x0.src = x1 },
      _1757: x0 => x0.naturalWidth,
      _1758: x0 => x0.naturalHeight,
      _1765: x0 => x0.offsetX,
      _1766: x0 => x0.offsetY,
      _1767: x0 => x0.button,
      _1774: x0 => x0.status,
      _1775: (x0,x1) => { x0.responseType = x1 },
      _1777: x0 => x0.response,
      _1826: (x0,x1) => { x0.responseType = x1 },
      _1827: x0 => x0.response,
      _1902: x0 => x0.style,
      _2379: (x0,x1) => { x0.src = x1 },
      _2386: (x0,x1) => { x0.allow = x1 },
      _2398: x0 => x0.contentWindow,
      _2831: (x0,x1) => { x0.accept = x1 },
      _2845: x0 => x0.files,
      _2871: (x0,x1) => { x0.multiple = x1 },
      _2889: (x0,x1) => { x0.type = x1 },
      _3587: (x0,x1) => { x0.dropEffect = x1 },
      _3592: x0 => x0.files,
      _3604: x0 => x0.dataTransfer,
      _3608: () => globalThis.window,
      _3650: x0 => x0.location,
      _3651: x0 => x0.history,
      _3667: x0 => x0.parent,
      _3669: x0 => x0.navigator,
      _3924: x0 => x0.isSecureContext,
      _3925: x0 => x0.crossOriginIsolated,
      _3928: x0 => x0.performance,
      _3933: x0 => x0.localStorage,
      _3941: x0 => x0.origin,
      _3950: x0 => x0.pathname,
      _3964: x0 => x0.state,
      _3989: x0 => x0.message,
      _4051: x0 => x0.appVersion,
      _4052: x0 => x0.platform,
      _4055: x0 => x0.userAgent,
      _4056: x0 => x0.vendor,
      _4106: x0 => x0.data,
      _4107: x0 => x0.origin,
      _4479: x0 => x0.readyState,
      _4488: x0 => x0.protocol,
      _4492: (x0,x1) => { x0.binaryType = x1 },
      _4495: x0 => x0.code,
      _4496: x0 => x0.reason,
      _6163: x0 => x0.type,
      _6204: x0 => x0.signal,
      _6262: x0 => x0.parentNode,
      _6276: () => globalThis.document,
      _6358: x0 => x0.body,
      _6401: x0 => x0.activeElement,
      _7035: x0 => x0.offsetX,
      _7036: x0 => x0.offsetY,
      _7121: x0 => x0.key,
      _7122: x0 => x0.code,
      _7123: x0 => x0.location,
      _7124: x0 => x0.ctrlKey,
      _7125: x0 => x0.shiftKey,
      _7126: x0 => x0.altKey,
      _7127: x0 => x0.metaKey,
      _7128: x0 => x0.repeat,
      _7129: x0 => x0.isComposing,
      _7131: x0 => x0.keyCode,
      _8035: x0 => x0.value,
      _8037: x0 => x0.done,
      _8217: x0 => x0.size,
      _8218: x0 => x0.type,
      _8225: x0 => x0.name,
      _8226: x0 => x0.lastModified,
      _8231: x0 => x0.length,
      _8237: x0 => x0.result,
      _8732: x0 => x0.url,
      _8734: x0 => x0.status,
      _8736: x0 => x0.statusText,
      _8737: x0 => x0.headers,
      _8738: x0 => x0.body,
      _10820: (x0,x1) => { x0.backgroundColor = x1 },
      _10866: (x0,x1) => { x0.border = x1 },
      _11144: (x0,x1) => { x0.display = x1 },
      _11308: (x0,x1) => { x0.height = x1 },
      _11998: (x0,x1) => { x0.width = x1 },
      _12366: x0 => x0.name,
      _13085: () => globalThis.console,

    };

    const baseImports = {
      dart2wasm: dart2wasm,
      Math: Math,
      Date: Date,
      Object: Object,
      Array: Array,
      Reflect: Reflect,
      S: new Proxy({}, { get(_, prop) { return prop; } }),

    };

    const jsStringPolyfill = {
      "charCodeAt": (s, i) => s.charCodeAt(i),
      "compare": (s1, s2) => {
        if (s1 < s2) return -1;
        if (s1 > s2) return 1;
        return 0;
      },
      "concat": (s1, s2) => s1 + s2,
      "equals": (s1, s2) => s1 === s2,
      "fromCharCode": (i) => String.fromCharCode(i),
      "length": (s) => s.length,
      "substring": (s, a, b) => s.substring(a, b),
      "fromCharCodeArray": (a, start, end) => {
        if (end <= start) return '';

        const read = dartInstance.exports.$wasmI16ArrayGet;
        let result = '';
        let index = start;
        const chunkLength = Math.min(end - index, 500);
        let array = new Array(chunkLength);
        while (index < end) {
          const newChunkLength = Math.min(end - index, 500);
          for (let i = 0; i < newChunkLength; i++) {
            array[i] = read(a, index++);
          }
          if (newChunkLength < chunkLength) {
            array = array.slice(0, newChunkLength);
          }
          result += String.fromCharCode(...array);
        }
        return result;
      },
      "intoCharCodeArray": (s, a, start) => {
        if (s === '') return 0;

        const write = dartInstance.exports.$wasmI16ArraySet;
        for (var i = 0; i < s.length; ++i) {
          write(a, start++, s.charCodeAt(i));
        }
        return s.length;
      },
      "test": (s) => typeof s == "string",
    };


    

    dartInstance = await WebAssembly.instantiate(this.module, {
      ...baseImports,
      ...additionalImports,
      
      "wasm:js-string": jsStringPolyfill,
    });

    return new InstantiatedApp(this, dartInstance);
  }
}

class InstantiatedApp {
  constructor(compiledApp, instantiatedModule) {
    this.compiledApp = compiledApp;
    this.instantiatedModule = instantiatedModule;
  }

  // Call the main function with the given arguments.
  invokeMain(...args) {
    this.instantiatedModule.exports.$invokeMain(args);
  }
}
