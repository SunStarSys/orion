(function (global, factory) {
  typeof exports === 'object' && typeof module !== 'undefined' ? factory(exports) :
  typeof define === 'function' && define.amd ? define(['exports'], factory) :
  (global = typeof globalThis !== 'undefined' ? globalThis : global || self, factory(global["@hpcc-js/wasm"] = {}));
})(this, (function (exports) { 'use strict';

  var cpp = (() => {
    var _scriptDir = typeof document !== 'undefined' && document.currentScript ? document.currentScript.src : undefined;
    
    return (
  function(cpp) {
    cpp = cpp || {};

  var Module=typeof cpp!="undefined"?cpp:{};var readyPromiseResolve,readyPromiseReject;Module["ready"]=new Promise(function(resolve,reject){readyPromiseResolve=resolve;readyPromiseReject=reject;});var moduleOverrides=Object.assign({},Module);var thisProgram="./this.program";var ENVIRONMENT_IS_WEB=true;var scriptDirectory="";function locateFile(path){if(Module["locateFile"]){return Module["locateFile"](path,scriptDirectory)}return scriptDirectory+path}var readBinary;{if(typeof document!="undefined"&&document.currentScript){scriptDirectory=document.currentScript.src;}if(_scriptDir){scriptDirectory=_scriptDir;}if(scriptDirectory.indexOf("blob:")!==0){scriptDirectory=scriptDirectory.substr(0,scriptDirectory.replace(/[?#].*/,"").lastIndexOf("/")+1);}else {scriptDirectory="";}}var out=Module["print"]||console.log.bind(console);var err=Module["printErr"]||console.warn.bind(console);Object.assign(Module,moduleOverrides);moduleOverrides=null;if(Module["arguments"])Module["arguments"];if(Module["thisProgram"])thisProgram=Module["thisProgram"];if(Module["quit"])Module["quit"];var wasmBinary;if(Module["wasmBinary"])wasmBinary=Module["wasmBinary"];Module["noExitRuntime"]||true;if(typeof WebAssembly!="object"){abort("no native wasm support detected");}var wasmMemory;var ABORT=false;function assert(condition,text){if(!condition){abort(text);}}var UTF8Decoder=typeof TextDecoder!="undefined"?new TextDecoder("utf8"):undefined;function UTF8ArrayToString(heapOrArray,idx,maxBytesToRead){var endIdx=idx+maxBytesToRead;var endPtr=idx;while(heapOrArray[endPtr]&&!(endPtr>=endIdx))++endPtr;if(endPtr-idx>16&&heapOrArray.buffer&&UTF8Decoder){return UTF8Decoder.decode(heapOrArray.subarray(idx,endPtr))}var str="";while(idx<endPtr){var u0=heapOrArray[idx++];if(!(u0&128)){str+=String.fromCharCode(u0);continue}var u1=heapOrArray[idx++]&63;if((u0&224)==192){str+=String.fromCharCode((u0&31)<<6|u1);continue}var u2=heapOrArray[idx++]&63;if((u0&240)==224){u0=(u0&15)<<12|u1<<6|u2;}else {u0=(u0&7)<<18|u1<<12|u2<<6|heapOrArray[idx++]&63;}if(u0<65536){str+=String.fromCharCode(u0);}else {var ch=u0-65536;str+=String.fromCharCode(55296|ch>>10,56320|ch&1023);}}return str}function UTF8ToString(ptr,maxBytesToRead){return ptr?UTF8ArrayToString(HEAPU8,ptr,maxBytesToRead):""}function stringToUTF8Array(str,heap,outIdx,maxBytesToWrite){if(!(maxBytesToWrite>0))return 0;var startIdx=outIdx;var endIdx=outIdx+maxBytesToWrite-1;for(var i=0;i<str.length;++i){var u=str.charCodeAt(i);if(u>=55296&&u<=57343){var u1=str.charCodeAt(++i);u=65536+((u&1023)<<10)|u1&1023;}if(u<=127){if(outIdx>=endIdx)break;heap[outIdx++]=u;}else if(u<=2047){if(outIdx+1>=endIdx)break;heap[outIdx++]=192|u>>6;heap[outIdx++]=128|u&63;}else if(u<=65535){if(outIdx+2>=endIdx)break;heap[outIdx++]=224|u>>12;heap[outIdx++]=128|u>>6&63;heap[outIdx++]=128|u&63;}else {if(outIdx+3>=endIdx)break;heap[outIdx++]=240|u>>18;heap[outIdx++]=128|u>>12&63;heap[outIdx++]=128|u>>6&63;heap[outIdx++]=128|u&63;}}heap[outIdx]=0;return outIdx-startIdx}function lengthBytesUTF8(str){var len=0;for(var i=0;i<str.length;++i){var c=str.charCodeAt(i);if(c<=127){len++;}else if(c<=2047){len+=2;}else if(c>=55296&&c<=57343){len+=4;++i;}else {len+=3;}}return len}var buffer,HEAP8,HEAPU8,HEAP32,HEAPU32,HEAPF64;function updateGlobalBufferAndViews(buf){buffer=buf;Module["HEAP8"]=HEAP8=new Int8Array(buf);Module["HEAP16"]=new Int16Array(buf);Module["HEAP32"]=HEAP32=new Int32Array(buf);Module["HEAPU8"]=HEAPU8=new Uint8Array(buf);Module["HEAPU16"]=new Uint16Array(buf);Module["HEAPU32"]=HEAPU32=new Uint32Array(buf);Module["HEAPF32"]=new Float32Array(buf);Module["HEAPF64"]=HEAPF64=new Float64Array(buf);}Module["INITIAL_MEMORY"]||16777216;var __ATPRERUN__=[];var __ATINIT__=[];var __ATPOSTRUN__=[];function preRun(){if(Module["preRun"]){if(typeof Module["preRun"]=="function")Module["preRun"]=[Module["preRun"]];while(Module["preRun"].length){addOnPreRun(Module["preRun"].shift());}}callRuntimeCallbacks(__ATPRERUN__);}function initRuntime(){callRuntimeCallbacks(__ATINIT__);}function postRun(){if(Module["postRun"]){if(typeof Module["postRun"]=="function")Module["postRun"]=[Module["postRun"]];while(Module["postRun"].length){addOnPostRun(Module["postRun"].shift());}}callRuntimeCallbacks(__ATPOSTRUN__);}function addOnPreRun(cb){__ATPRERUN__.unshift(cb);}function addOnInit(cb){__ATINIT__.unshift(cb);}function addOnPostRun(cb){__ATPOSTRUN__.unshift(cb);}var runDependencies=0;var dependenciesFulfilled=null;function addRunDependency(id){runDependencies++;if(Module["monitorRunDependencies"]){Module["monitorRunDependencies"](runDependencies);}}function removeRunDependency(id){runDependencies--;if(Module["monitorRunDependencies"]){Module["monitorRunDependencies"](runDependencies);}if(runDependencies==0){if(dependenciesFulfilled){var callback=dependenciesFulfilled;dependenciesFulfilled=null;callback();}}}function abort(what){{if(Module["onAbort"]){Module["onAbort"](what);}}what="Aborted("+what+")";err(what);ABORT=true;what+=". Build with -sASSERTIONS for more info.";var e=new WebAssembly.RuntimeError(what);readyPromiseReject(e);throw e}var dataURIPrefix="data:application/octet-stream;base64,";function isDataURI(filename){return filename.startsWith(dataURIPrefix)}var wasmBinaryFile;wasmBinaryFile="expatlib.wasm";if(!isDataURI(wasmBinaryFile)){wasmBinaryFile=locateFile(wasmBinaryFile);}function getBinary(file){try{if(file==wasmBinaryFile&&wasmBinary){return new Uint8Array(wasmBinary)}if(readBinary);throw "both async and sync fetching of the wasm failed"}catch(err){abort(err);}}function getBinaryPromise(){if(!wasmBinary&&(ENVIRONMENT_IS_WEB)){if(typeof fetch=="function"){return fetch(wasmBinaryFile,{credentials:"same-origin"}).then(function(response){if(!response["ok"]){throw "failed to load wasm binary file at '"+wasmBinaryFile+"'"}return response["arrayBuffer"]()}).catch(function(){return getBinary(wasmBinaryFile)})}}return Promise.resolve().then(function(){return getBinary(wasmBinaryFile)})}function createWasm(){var info={"a":asmLibraryArg};function receiveInstance(instance,module){var exports=instance.exports;Module["asm"]=exports;wasmMemory=Module["asm"]["m"];updateGlobalBufferAndViews(wasmMemory.buffer);Module["asm"]["G"];addOnInit(Module["asm"]["n"]);removeRunDependency();}addRunDependency();function receiveInstantiationResult(result){receiveInstance(result["instance"]);}function instantiateArrayBuffer(receiver){return getBinaryPromise().then(function(binary){return WebAssembly.instantiate(binary,info)}).then(function(instance){return instance}).then(receiver,function(reason){err("failed to asynchronously prepare wasm: "+reason);abort(reason);})}function instantiateAsync(){if(!wasmBinary&&typeof WebAssembly.instantiateStreaming=="function"&&!isDataURI(wasmBinaryFile)&&typeof fetch=="function"){return fetch(wasmBinaryFile,{credentials:"same-origin"}).then(function(response){var result=WebAssembly.instantiateStreaming(response,info);return result.then(receiveInstantiationResult,function(reason){err("wasm streaming compile failed: "+reason);err("falling back to ArrayBuffer instantiation");return instantiateArrayBuffer(receiveInstantiationResult)})})}else {return instantiateArrayBuffer(receiveInstantiationResult)}}if(Module["instantiateWasm"]){try{var exports=Module["instantiateWasm"](info,receiveInstance);return exports}catch(e){err("Module.instantiateWasm callback failed with error: "+e);return false}}instantiateAsync().catch(readyPromiseReject);return {}}var ASM_CONSTS={11534:$0=>{var self=Module["getCache"](Module["CExpatJS"])[$0];if(!self.hasOwnProperty("startElement"))throw "a JSImplementation must implement all functions, you forgot CExpatJS::startElement.";self["startElement"]();},11752:$0=>{var self=Module["getCache"](Module["CExpatJS"])[$0];if(!self.hasOwnProperty("endElement"))throw "a JSImplementation must implement all functions, you forgot CExpatJS::endElement.";self["endElement"]();},11964:$0=>{var self=Module["getCache"](Module["CExpatJS"])[$0];if(!self.hasOwnProperty("characterData"))throw "a JSImplementation must implement all functions, you forgot CExpatJS::characterData.";self["characterData"]();}};function callRuntimeCallbacks(callbacks){while(callbacks.length>0){callbacks.shift()(Module);}}function ___syscall_openat(dirfd,path,flags,varargs){}function __emscripten_date_now(){return Date.now()}function _abort(){abort("");}var readAsmConstArgsArray=[];function readAsmConstArgs(sigPtr,buf){readAsmConstArgsArray.length=0;var ch;buf>>=2;while(ch=HEAPU8[sigPtr++]){buf+=ch!=105&buf;readAsmConstArgsArray.push(ch==105?HEAP32[buf]:HEAPF64[buf++>>1]);++buf;}return readAsmConstArgsArray}function _emscripten_asm_const_int(code,sigPtr,argbuf){var args=readAsmConstArgs(sigPtr,argbuf);return ASM_CONSTS[code].apply(null,args)}function _emscripten_memcpy_big(dest,src,num){HEAPU8.copyWithin(dest,src,src+num);}function getHeapMax(){return 2147483648}function emscripten_realloc_buffer(size){try{wasmMemory.grow(size-buffer.byteLength+65535>>>16);updateGlobalBufferAndViews(wasmMemory.buffer);return 1}catch(e){}}function _emscripten_resize_heap(requestedSize){var oldSize=HEAPU8.length;requestedSize=requestedSize>>>0;var maxHeapSize=getHeapMax();if(requestedSize>maxHeapSize){return false}let alignUp=(x,multiple)=>x+(multiple-x%multiple)%multiple;for(var cutDown=1;cutDown<=4;cutDown*=2){var overGrownHeapSize=oldSize*(1+.2/cutDown);overGrownHeapSize=Math.min(overGrownHeapSize,requestedSize+100663296);var newSize=Math.min(maxHeapSize,alignUp(Math.max(requestedSize,overGrownHeapSize),65536));var replacement=emscripten_realloc_buffer(newSize);if(replacement){return true}}return false}var ENV={};function getExecutableName(){return thisProgram||"./this.program"}function getEnvStrings(){if(!getEnvStrings.strings){var lang=(typeof navigator=="object"&&navigator.languages&&navigator.languages[0]||"C").replace("-","_")+".UTF-8";var env={"USER":"web_user","LOGNAME":"web_user","PATH":"/","PWD":"/","HOME":"/home/web_user","LANG":lang,"_":getExecutableName()};for(var x in ENV){if(ENV[x]===undefined)delete env[x];else env[x]=ENV[x];}var strings=[];for(var x in env){strings.push(x+"="+env[x]);}getEnvStrings.strings=strings;}return getEnvStrings.strings}function writeAsciiToMemory(str,buffer,dontAddNull){for(var i=0;i<str.length;++i){HEAP8[buffer++>>0]=str.charCodeAt(i);}if(!dontAddNull)HEAP8[buffer>>0]=0;}function _environ_get(__environ,environ_buf){var bufSize=0;getEnvStrings().forEach(function(string,i){var ptr=environ_buf+bufSize;HEAPU32[__environ+i*4>>2]=ptr;writeAsciiToMemory(string,ptr);bufSize+=string.length+1;});return 0}function _environ_sizes_get(penviron_count,penviron_buf_size){var strings=getEnvStrings();HEAPU32[penviron_count>>2]=strings.length;var bufSize=0;strings.forEach(function(string){bufSize+=string.length+1;});HEAPU32[penviron_buf_size>>2]=bufSize;return 0}function _fd_close(fd){return 52}function _fd_read(fd,iov,iovcnt,pnum){return 52}function _fd_seek(fd,offset_low,offset_high,whence,newOffset){return 70}var printCharBuffers=[null,[],[]];function printChar(stream,curr){var buffer=printCharBuffers[stream];if(curr===0||curr===10){(stream===1?out:err)(UTF8ArrayToString(buffer,0));buffer.length=0;}else {buffer.push(curr);}}function _fd_write(fd,iov,iovcnt,pnum){var num=0;for(var i=0;i<iovcnt;i++){var ptr=HEAPU32[iov>>2];var len=HEAPU32[iov+4>>2];iov+=8;for(var j=0;j<len;j++){printChar(fd,HEAPU8[ptr+j]);}num+=len;}HEAPU32[pnum>>2]=num;return 0}function intArrayFromString(stringy,dontAddNull,length){var len=length>0?length:lengthBytesUTF8(stringy)+1;var u8array=new Array(len);var numBytesWritten=stringToUTF8Array(stringy,u8array,0,u8array.length);if(dontAddNull)u8array.length=numBytesWritten;return u8array}var asmLibraryArg={"g":___syscall_openat,"j":__emscripten_date_now,"c":_abort,"a":_emscripten_asm_const_int,"k":_emscripten_memcpy_big,"e":_emscripten_resize_heap,"h":_environ_get,"i":_environ_sizes_get,"d":_fd_close,"f":_fd_read,"l":_fd_seek,"b":_fd_write};createWasm();Module["___wasm_call_ctors"]=function(){return (Module["___wasm_call_ctors"]=Module["asm"]["n"]).apply(null,arguments)};var _emscripten_bind_CExpat_CExpat_0=Module["_emscripten_bind_CExpat_CExpat_0"]=function(){return (_emscripten_bind_CExpat_CExpat_0=Module["_emscripten_bind_CExpat_CExpat_0"]=Module["asm"]["o"]).apply(null,arguments)};var _emscripten_bind_CExpat_version_0=Module["_emscripten_bind_CExpat_version_0"]=function(){return (_emscripten_bind_CExpat_version_0=Module["_emscripten_bind_CExpat_version_0"]=Module["asm"]["p"]).apply(null,arguments)};var _emscripten_bind_CExpat_create_0=Module["_emscripten_bind_CExpat_create_0"]=function(){return (_emscripten_bind_CExpat_create_0=Module["_emscripten_bind_CExpat_create_0"]=Module["asm"]["q"]).apply(null,arguments)};var _emscripten_bind_CExpat_destroy_0=Module["_emscripten_bind_CExpat_destroy_0"]=function(){return (_emscripten_bind_CExpat_destroy_0=Module["_emscripten_bind_CExpat_destroy_0"]=Module["asm"]["r"]).apply(null,arguments)};var _emscripten_bind_CExpat_parse_1=Module["_emscripten_bind_CExpat_parse_1"]=function(){return (_emscripten_bind_CExpat_parse_1=Module["_emscripten_bind_CExpat_parse_1"]=Module["asm"]["s"]).apply(null,arguments)};var _emscripten_bind_CExpat_tag_0=Module["_emscripten_bind_CExpat_tag_0"]=function(){return (_emscripten_bind_CExpat_tag_0=Module["_emscripten_bind_CExpat_tag_0"]=Module["asm"]["t"]).apply(null,arguments)};var _emscripten_bind_CExpat_attrs_0=Module["_emscripten_bind_CExpat_attrs_0"]=function(){return (_emscripten_bind_CExpat_attrs_0=Module["_emscripten_bind_CExpat_attrs_0"]=Module["asm"]["u"]).apply(null,arguments)};var _emscripten_bind_CExpat_content_0=Module["_emscripten_bind_CExpat_content_0"]=function(){return (_emscripten_bind_CExpat_content_0=Module["_emscripten_bind_CExpat_content_0"]=Module["asm"]["v"]).apply(null,arguments)};var _emscripten_bind_CExpat_startElement_0=Module["_emscripten_bind_CExpat_startElement_0"]=function(){return (_emscripten_bind_CExpat_startElement_0=Module["_emscripten_bind_CExpat_startElement_0"]=Module["asm"]["w"]).apply(null,arguments)};var _emscripten_bind_CExpat_endElement_0=Module["_emscripten_bind_CExpat_endElement_0"]=function(){return (_emscripten_bind_CExpat_endElement_0=Module["_emscripten_bind_CExpat_endElement_0"]=Module["asm"]["x"]).apply(null,arguments)};var _emscripten_bind_CExpat_characterData_0=Module["_emscripten_bind_CExpat_characterData_0"]=function(){return (_emscripten_bind_CExpat_characterData_0=Module["_emscripten_bind_CExpat_characterData_0"]=Module["asm"]["y"]).apply(null,arguments)};var _emscripten_bind_CExpat___destroy___0=Module["_emscripten_bind_CExpat___destroy___0"]=function(){return (_emscripten_bind_CExpat___destroy___0=Module["_emscripten_bind_CExpat___destroy___0"]=Module["asm"]["z"]).apply(null,arguments)};var _emscripten_bind_VoidPtr___destroy___0=Module["_emscripten_bind_VoidPtr___destroy___0"]=function(){return (_emscripten_bind_VoidPtr___destroy___0=Module["_emscripten_bind_VoidPtr___destroy___0"]=Module["asm"]["A"]).apply(null,arguments)};var _emscripten_bind_CExpatJS_CExpatJS_0=Module["_emscripten_bind_CExpatJS_CExpatJS_0"]=function(){return (_emscripten_bind_CExpatJS_CExpatJS_0=Module["_emscripten_bind_CExpatJS_CExpatJS_0"]=Module["asm"]["B"]).apply(null,arguments)};var _emscripten_bind_CExpatJS_startElement_0=Module["_emscripten_bind_CExpatJS_startElement_0"]=function(){return (_emscripten_bind_CExpatJS_startElement_0=Module["_emscripten_bind_CExpatJS_startElement_0"]=Module["asm"]["C"]).apply(null,arguments)};var _emscripten_bind_CExpatJS_endElement_0=Module["_emscripten_bind_CExpatJS_endElement_0"]=function(){return (_emscripten_bind_CExpatJS_endElement_0=Module["_emscripten_bind_CExpatJS_endElement_0"]=Module["asm"]["D"]).apply(null,arguments)};var _emscripten_bind_CExpatJS_characterData_0=Module["_emscripten_bind_CExpatJS_characterData_0"]=function(){return (_emscripten_bind_CExpatJS_characterData_0=Module["_emscripten_bind_CExpatJS_characterData_0"]=Module["asm"]["E"]).apply(null,arguments)};var _emscripten_bind_CExpatJS___destroy___0=Module["_emscripten_bind_CExpatJS___destroy___0"]=function(){return (_emscripten_bind_CExpatJS___destroy___0=Module["_emscripten_bind_CExpatJS___destroy___0"]=Module["asm"]["F"]).apply(null,arguments)};Module["_malloc"]=function(){return (Module["_malloc"]=Module["asm"]["H"]).apply(null,arguments)};Module["___start_em_js"]=11436;Module["___stop_em_js"]=11534;var calledRun;dependenciesFulfilled=function runCaller(){if(!calledRun)run();if(!calledRun)dependenciesFulfilled=runCaller;};function run(args){if(runDependencies>0){return}preRun();if(runDependencies>0){return}function doRun(){if(calledRun)return;calledRun=true;Module["calledRun"]=true;if(ABORT)return;initRuntime();readyPromiseResolve(Module);if(Module["onRuntimeInitialized"])Module["onRuntimeInitialized"]();postRun();}if(Module["setStatus"]){Module["setStatus"]("Running...");setTimeout(function(){setTimeout(function(){Module["setStatus"]("");},1);doRun();},1);}else {doRun();}}if(Module["preInit"]){if(typeof Module["preInit"]=="function")Module["preInit"]=[Module["preInit"]];while(Module["preInit"].length>0){Module["preInit"].pop()();}}run();function WrapperObject(){}WrapperObject.prototype=Object.create(WrapperObject.prototype);WrapperObject.prototype.constructor=WrapperObject;WrapperObject.prototype.__class__=WrapperObject;WrapperObject.__cache__={};Module["WrapperObject"]=WrapperObject;function getCache(__class__){return (__class__||WrapperObject).__cache__}Module["getCache"]=getCache;function wrapPointer(ptr,__class__){var cache=getCache(__class__);var ret=cache[ptr];if(ret)return ret;ret=Object.create((__class__||WrapperObject).prototype);ret.ptr=ptr;return cache[ptr]=ret}Module["wrapPointer"]=wrapPointer;function castObject(obj,__class__){return wrapPointer(obj.ptr,__class__)}Module["castObject"]=castObject;Module["NULL"]=wrapPointer(0);function destroy(obj){if(!obj["__destroy__"])throw "Error: Cannot destroy object. (Did you create it yourself?)";obj["__destroy__"]();delete getCache(obj.__class__)[obj.ptr];}Module["destroy"]=destroy;function compare(obj1,obj2){return obj1.ptr===obj2.ptr}Module["compare"]=compare;function getPointer(obj){return obj.ptr}Module["getPointer"]=getPointer;function getClass(obj){return obj.__class__}Module["getClass"]=getClass;var ensureCache={buffer:0,size:0,pos:0,temps:[],needed:0,prepare:function(){if(ensureCache.needed){for(var i=0;i<ensureCache.temps.length;i++){Module["_free"](ensureCache.temps[i]);}ensureCache.temps.length=0;Module["_free"](ensureCache.buffer);ensureCache.buffer=0;ensureCache.size+=ensureCache.needed;ensureCache.needed=0;}if(!ensureCache.buffer){ensureCache.size+=128;ensureCache.buffer=Module["_malloc"](ensureCache.size);assert(ensureCache.buffer);}ensureCache.pos=0;},alloc:function(array,view){assert(ensureCache.buffer);var bytes=view.BYTES_PER_ELEMENT;var len=array.length*bytes;len=len+7&-8;var ret;if(ensureCache.pos+len>=ensureCache.size){assert(len>0);ensureCache.needed+=len;ret=Module["_malloc"](len);ensureCache.temps.push(ret);}else {ret=ensureCache.buffer+ensureCache.pos;ensureCache.pos+=len;}return ret},copy:function(array,view,offset){offset>>>=0;var bytes=view.BYTES_PER_ELEMENT;switch(bytes){case 2:offset>>>=1;break;case 4:offset>>>=2;break;case 8:offset>>>=3;break}for(var i=0;i<array.length;i++){view[offset+i]=array[i];}}};function ensureString(value){if(typeof value==="string"){var intArray=intArrayFromString(value);var offset=ensureCache.alloc(intArray,HEAP8);ensureCache.copy(intArray,HEAP8,offset);return offset}return value}function CExpat(){this.ptr=_emscripten_bind_CExpat_CExpat_0();getCache(CExpat)[this.ptr]=this;}CExpat.prototype=Object.create(WrapperObject.prototype);CExpat.prototype.constructor=CExpat;CExpat.prototype.__class__=CExpat;CExpat.__cache__={};Module["CExpat"]=CExpat;CExpat.prototype["version"]=CExpat.prototype.version=function(){var self=this.ptr;return UTF8ToString(_emscripten_bind_CExpat_version_0(self))};CExpat.prototype["create"]=CExpat.prototype.create=function(){var self=this.ptr;return !!_emscripten_bind_CExpat_create_0(self)};CExpat.prototype["destroy"]=CExpat.prototype.destroy=function(){var self=this.ptr;_emscripten_bind_CExpat_destroy_0(self);};CExpat.prototype["parse"]=CExpat.prototype.parse=function(xml){var self=this.ptr;ensureCache.prepare();if(xml&&typeof xml==="object")xml=xml.ptr;else xml=ensureString(xml);return !!_emscripten_bind_CExpat_parse_1(self,xml)};CExpat.prototype["tag"]=CExpat.prototype.tag=function(){var self=this.ptr;return UTF8ToString(_emscripten_bind_CExpat_tag_0(self))};CExpat.prototype["attrs"]=CExpat.prototype.attrs=function(){var self=this.ptr;return UTF8ToString(_emscripten_bind_CExpat_attrs_0(self))};CExpat.prototype["content"]=CExpat.prototype.content=function(){var self=this.ptr;return UTF8ToString(_emscripten_bind_CExpat_content_0(self))};CExpat.prototype["startElement"]=CExpat.prototype.startElement=function(){var self=this.ptr;_emscripten_bind_CExpat_startElement_0(self);};CExpat.prototype["endElement"]=CExpat.prototype.endElement=function(){var self=this.ptr;_emscripten_bind_CExpat_endElement_0(self);};CExpat.prototype["characterData"]=CExpat.prototype.characterData=function(){var self=this.ptr;_emscripten_bind_CExpat_characterData_0(self);};CExpat.prototype["__destroy__"]=CExpat.prototype.__destroy__=function(){var self=this.ptr;_emscripten_bind_CExpat___destroy___0(self);};function VoidPtr(){throw "cannot construct a VoidPtr, no constructor in IDL"}VoidPtr.prototype=Object.create(WrapperObject.prototype);VoidPtr.prototype.constructor=VoidPtr;VoidPtr.prototype.__class__=VoidPtr;VoidPtr.__cache__={};Module["VoidPtr"]=VoidPtr;VoidPtr.prototype["__destroy__"]=VoidPtr.prototype.__destroy__=function(){var self=this.ptr;_emscripten_bind_VoidPtr___destroy___0(self);};function CExpatJS(){this.ptr=_emscripten_bind_CExpatJS_CExpatJS_0();getCache(CExpatJS)[this.ptr]=this;}CExpatJS.prototype=Object.create(CExpat.prototype);CExpatJS.prototype.constructor=CExpatJS;CExpatJS.prototype.__class__=CExpatJS;CExpatJS.__cache__={};Module["CExpatJS"]=CExpatJS;CExpatJS.prototype["startElement"]=CExpatJS.prototype.startElement=function(){var self=this.ptr;_emscripten_bind_CExpatJS_startElement_0(self);};CExpatJS.prototype["endElement"]=CExpatJS.prototype.endElement=function(){var self=this.ptr;_emscripten_bind_CExpatJS_endElement_0(self);};CExpatJS.prototype["characterData"]=CExpatJS.prototype.characterData=function(){var self=this.ptr;_emscripten_bind_CExpatJS_characterData_0(self);};CExpatJS.prototype["__destroy__"]=CExpatJS.prototype.__destroy__=function(){var self=this.ptr;_emscripten_bind_CExpatJS___destroy___0(self);};


    return cpp.ready
  }
  );
  })();

  var expatlib = /*#__PURE__*/Object.freeze({
    __proto__: null,
    'default': cpp
  });

  function getGlobal() {
      if (typeof self !== "undefined") {
          return self;
      }
      if (typeof window !== "undefined") {
          return window;
      }
      if (typeof global !== "undefined") {
          return global;
      }
      throw new Error("unable to locate global object");
  }
  const globalNS = getGlobal();
  let _wasmFolder = globalNS.__hpcc_wasmFolder || undefined;
  function wasmFolder(_) {
      if (!arguments.length)
          return _wasmFolder;
      const retVal = _wasmFolder;
      _wasmFolder = _;
      return retVal;
  }
  function trimEnd(str, charToRemove) {
      while (str.charAt(str.length - 1) === charToRemove) {
          str = str.substring(0, str.length - 1);
      }
      return str;
  }
  function trimStart(str, charToRemove) {
      while (str.charAt(0) === charToRemove) {
          str = str.substring(1);
      }
      return str;
  }
  let scriptDir = typeof document !== 'undefined' && document.currentScript ? document.currentScript.src :
      typeof __filename !== 'undefined' ? __filename :
          typeof document !== 'undefined' && document.currentScript ? document.currentScript.src :
              "";
  scriptDir = scriptDir.substr(0, scriptDir.replace(/[?#].*/, "").lastIndexOf('/') + 1);
  async function browserFetch(wasmUrl) {
      return fetch(wasmUrl, { credentials: 'same-origin' }).then(response => {
          if (!response.ok) {
              throw "failed to load wasm binary file at '" + wasmUrl + "'";
          }
          return response.arrayBuffer();
      }).catch(e => {
          throw e;
      });
  }
  const g_wasmCache = {};
  async function _loadWasm(_wasmLib, wasmUrl, wasmBinary) {
      const wasmLib = _wasmLib.default || _wasmLib;
      if (!wasmBinary) {
          wasmBinary = await browserFetch(wasmUrl);
      }
      return await wasmLib({
          "wasmBinary": wasmBinary
      });
  }
  async function loadWasm(_wasmLib, filename, wf, wasmBinary) {
      const wasmUrl = `${trimEnd(wf || wasmFolder() || scriptDir || ".", "/")}/${trimStart(`${filename}.wasm`, "/")}`;
      if (!g_wasmCache[wasmUrl]) {
          g_wasmCache[wasmUrl] = _loadWasm(_wasmLib, wasmUrl, wasmBinary);
      }
      return g_wasmCache[wasmUrl];
  }

  // @ts-ignore
  class StackElement {
      constructor(tag, attrs) {
          this.tag = tag;
          this.attrs = attrs;
          this._content = "";
      }
      get content() {
          return this._content;
      }
      appendContent(content) {
          this._content += content;
      }
  }
  class StackParser {
      constructor() {
          this._stack = [];
      }
      parse(xml, wasmFolder, wasmBinary) {
          return parse(xml, this, wasmFolder, wasmBinary);
      }
      top() {
          return this._stack[this._stack.length - 1];
      }
      startElement(tag, attrs) {
          const retVal = new StackElement(tag, attrs);
          this._stack.push(retVal);
          return retVal;
      }
      endElement(tag) {
          return this._stack.pop();
      }
      characterData(content) {
          this.top().appendContent(content);
      }
  }
  function parseAttrs(attrs) {
      const retVal = {};
      const keys = attrs;
      const sep = `${String.fromCharCode(1)}`;
      const sep2 = `${sep}${sep}`;
      keys.split(sep2).filter((key) => !!key).forEach((key) => {
          const parts = key.split(sep);
          retVal[parts[0]] = parts[1];
      });
      return retVal;
  }
  function expatVersion(wasmFolder, wasmBinary) {
      return loadWasm(expatlib, "expatlib", wasmFolder, wasmBinary).then(module => {
          return module.CExpat.prototype.version();
      });
  }
  function parse(xml, callback, wasmFolder, wasmBinary) {
      return loadWasm(expatlib, "expatlib", wasmFolder, wasmBinary).then(module => {
          const parser = new module.CExpatJS();
          parser.startElement = function () {
              callback.startElement(this.tag(), parseAttrs(this.attrs()));
          };
          parser.endElement = function () {
              callback.endElement(this.tag());
          };
          parser.characterData = function () {
              callback.characterData(this.content());
          };
          parser.create();
          const retVal = parser.parse(xml);
          parser.destroy();
          module.destroy(parser);
          return retVal;
      });
  }

  exports.StackElement = StackElement;
  exports.StackParser = StackParser;
  exports.expatVersion = expatVersion;
  exports.parse = parse;

  Object.defineProperty(exports, '__esModule', { value: true });

}));
//# sourceMappingURL=expat.js.map
