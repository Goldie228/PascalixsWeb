// @cropper/utils@2.0.1 downloaded from https://ga.jspm.io/npm:@cropper/utils@2.0.1/dist/utils.esm.raw.js

const t=typeof window!=="undefined"&&typeof window.document!=="undefined";const n=t?window:{};const e=!!t&&"ontouchstart"in n.document.documentElement;const o=!!t&&"PointerEvent"in n;const c="cropper";const s=`${c}-canvas`;const r=`${c}-crosshair`;const i=`${c}-grid`;const u=`${c}-handle`;const a=`${c}-image`;const f=`${c}-selection`;const d=`${c}-shade`;const p=`${c}-viewer`;const l="select";const h="move";const m="scale";const g="rotate";const w="transform";const y="none";const b="n-resize";const v="e-resize";const z="s-resize";const $="w-resize";const O="ne-resize";const E="nw-resize";const j="se-resize";const P="sw-resize";const C="action";const L=e?"touchend touchcancel":"mouseup";const N=e?"touchmove":"mousemove";const I=e?"touchstart":"mousedown";const M=o?"pointerdown":I;const A=o?"pointermove":N;const R=o?"pointerup pointercancel":L;const S="error";const T="keydown";const k="load";const x="resize";const B="wheel";const D="action";const F="actionend";const U="actionmove";const X="actionstart";const Y="change";const Z="transform";
/**
 * Check if the given value is a string.
 * @param {*} value The value to check.
 * @returns {boolean} Returns `true` if the given value is a string, else `false`.
 */function q(t){return typeof t==="string"}const G=Number.isNaN||n.isNaN;
/**
 * Check if the given value is a number.
 * @param {*} value The value to check.
 * @returns {boolean} Returns `true` if the given value is a number, else `false`.
 */function H(t){return typeof t==="number"&&!G(t)}
/**
 * Check if the given value is a positive number.
 * @param {*} value The value to check.
 * @returns {boolean} Returns `true` if the given value is a positive number, else `false`.
 */function J(t){return H(t)&&t>0&&t<Infinity}
/**
 * Check if the given value is undefined.
 * @param {*} value The value to check.
 * @returns {boolean} Returns `true` if the given value is undefined, else `false`.
 */function K(t){return typeof t==="undefined"}
/**
 * Check if the given value is an object.
 * @param {*} value - The value to check.
 * @returns {boolean} Returns `true` if the given value is an object, else `false`.
 */function Q(t){return typeof t==="object"&&t!==null}const{hasOwnProperty:V}=Object.prototype;
/**
 * Check if the given value is a plain object.
 * @param {*} value - The value to check.
 * @returns {boolean} Returns `true` if the given value is a plain object, else `false`.
 */function W(t){if(!Q(t))return false;try{const{constructor:n}=t;const{prototype:e}=n;return n&&e&&V.call(e,"isPrototypeOf")}catch(t){return false}}
/**
 * Check if the given value is a function.
 * @param {*} value The value to check.
 * @returns {boolean} Returns `true` if the given value is a function, else `false`.
 */function _(t){return typeof t==="function"}
/**
 * Check if the given node is an element.
 * @param {*} node The node to check.
 * @returns {boolean} Returns `true` if the given node is an element; otherwise, `false`.
 */function tt(t){return typeof t==="object"&&t!==null&&t.nodeType===1}const nt=/([a-z\d])([A-Z])/g;
/**
 * Transform the given string from camelCase to kebab-case.
 * @param {string} value The value to transform.
 * @returns {string} Returns the transformed value.
 */function et(t){return String(t).replace(nt,"$1-$2").toLowerCase()}const ot=/-[A-z\d]/g;
/**
 * Transform the given string from kebab-case to camelCase.
 * @param {string} value The value to transform.
 * @returns {string} Returns the transformed value.
 */function ct(t){return t.replace(ot,(t=>t.slice(1).toUpperCase()))}const st=/\s\s*/;
/**
 * Remove event listener from the event target.
 * {@link https://developer.mozilla.org/en-US/docs/Web/API/EventTarget/removeEventListener}
 * @param {EventTarget} target The target of the event.
 * @param {string} types The types of the event.
 * @param {EventListenerOrEventListenerObject} listener The listener of the event.
 * @param {EventListenerOptions} [options] The options specify characteristics about the event listener.
 */function rt(t,n,e,o){n.trim().split(st).forEach((n=>{t.removeEventListener(n,e,o)}))}
/**
 * Add event listener to the event target.
 * {@link https://developer.mozilla.org/en-US/docs/Web/API/EventTarget/addEventListener}
 * @param {EventTarget} target The target of the event.
 * @param {string} types The types of the event.
 * @param {EventListenerOrEventListenerObject} listener The listener of the event.
 * @param {AddEventListenerOptions} [options] The options specify characteristics about the event listener.
 */function it(t,n,e,o){n.trim().split(st).forEach((n=>{t.addEventListener(n,e,o)}))}
/**
 * Add once event listener to the event target.
 * @param {EventTarget} target The target of the event.
 * @param {string} types The types of the event.
 * @param {EventListenerOrEventListenerObject} listener The listener of the event.
 * @param {AddEventListenerOptions} [options] The options specify characteristics about the event listener.
 */function ut(t,n,e,o){it(t,n,e,Object.assign(Object.assign({},o),{once:true}))}const at={bubbles:true,cancelable:true,composed:true};
/**
 * Dispatch event on the event target.
 * {@link https://developer.mozilla.org/en-US/docs/Web/API/EventTarget/dispatchEvent}
 * @param {EventTarget} target The target of the event.
 * @param {string} type The name of the event.
 * @param {*} [detail] The data passed when initializing the event.
 * @param {CustomEventInit} [options] The other event options.
 * @returns {boolean} Returns the result value.
 */function ft(t,n,e,o){return t.dispatchEvent(new CustomEvent(n,Object.assign(Object.assign(Object.assign({},at),{detail:e}),o)))}const dt=Promise.resolve();
/**
 * Defers the callback to be executed after the next DOM update cycle.
 * @param {*} [context] The `this` context.
 * @param {Function} [callback] The callback to execute after the next DOM update cycle.
 * @returns {Promise} A promise that resolves to nothing.
 */function pt(t,n){return n?dt.then(t?n.bind(t):n):dt}
/**
 * Get the offset base on the document.
 * @param {Element} element The target element.
 * @returns {object} The offset data.
 */function lt(t){const{documentElement:e}=t.ownerDocument;const o=t.getBoundingClientRect();return{left:o.left+(n.pageXOffset-e.clientLeft),top:o.top+(n.pageYOffset-e.clientTop)}}const ht=/deg|g?rad|turn$/i;
/**
 * Convert an angle to a radian number.
 * {@link https://developer.mozilla.org/en-US/docs/Web/CSS/angle}
 * @param {number|string} angle The angle to convert.
 * @returns {number} Returns the radian number.
 */function mt(t){const n=parseFloat(t)||0;if(n!==0){const[e="rad"]=String(t).match(ht)||[];switch(e.toLowerCase()){case"deg":return n/360*(Math.PI*2);case"grad":return n/400*(Math.PI*2);case"turn":return n*(Math.PI*2)}}return n}const gt="contain";const wt="cover";
/**
 * Get the max sizes in a rectangle under the given aspect ratio.
 * @param {object} data The original sizes.
 * @param {string} [type] The adjust type.
 * @returns {object} Returns the result sizes.
 */function yt(t,n=gt){const{aspectRatio:e}=t;let{width:o,height:c}=t;const s=J(o);const r=J(c);if(s&&r){const t=c*e;n===gt&&t>o||n===wt&&t<o?c=o/e:o=c*e}else s?c=o/e:r&&(o=c*e);return{width:o,height:c}}
/**
 * Multiply multiple matrices.
 * @param {Array} matrix The first matrix.
 * @param {Array} args The rest matrices.
 * @returns {Array} Returns the result matrix.
 */function bt(t,...n){if(n.length===0)return t;const[e,o,c,s,r,i]=t;const[u,a,f,d,p,l]=n[0];t=[e*u+c*a,o*u+s*a,e*f+c*d,o*f+s*d,e*p+c*l+r,o*p+s*l+i];return bt(t,...n.slice(1))}export{h as ACTION_MOVE,y as ACTION_NONE,v as ACTION_RESIZE_EAST,b as ACTION_RESIZE_NORTH,O as ACTION_RESIZE_NORTHEAST,E as ACTION_RESIZE_NORTHWEST,z as ACTION_RESIZE_SOUTH,j as ACTION_RESIZE_SOUTHEAST,P as ACTION_RESIZE_SOUTHWEST,$ as ACTION_RESIZE_WEST,g as ACTION_ROTATE,m as ACTION_SCALE,l as ACTION_SELECT,w as ACTION_TRANSFORM,C as ATTRIBUTE_ACTION,s as CROPPER_CANVAS,r as CROPPER_CROSSHAIR,i as CROPPER_GIRD,u as CROPPER_HANDLE,a as CROPPER_IMAGE,f as CROPPER_SELECTION,d as CROPPER_SHADE,p as CROPPER_VIEWER,D as EVENT_ACTION,F as EVENT_ACTION_END,U as EVENT_ACTION_MOVE,X as EVENT_ACTION_START,Y as EVENT_CHANGE,S as EVENT_ERROR,T as EVENT_KEYDOWN,k as EVENT_LOAD,M as EVENT_POINTER_DOWN,A as EVENT_POINTER_MOVE,R as EVENT_POINTER_UP,x as EVENT_RESIZE,L as EVENT_TOUCH_END,N as EVENT_TOUCH_MOVE,I as EVENT_TOUCH_START,Z as EVENT_TRANSFORM,B as EVENT_WHEEL,o as HAS_POINTER_EVENT,t as IS_BROWSER,e as IS_TOUCH_DEVICE,c as NAMESPACE,n as WINDOW,ft as emit,yt as getAdjustedSizes,lt as getOffset,tt as isElement,_ as isFunction,G as isNaN,H as isNumber,Q as isObject,W as isPlainObject,J as isPositiveNumber,q as isString,K as isUndefined,bt as multiplyMatrices,pt as nextTick,rt as off,it as on,ut as once,mt as toAngleInRadian,ct as toCamelCase,et as toKebabCase};

