"use client";import {QRCodeSVG} from "qrcode.react";
export function QRCode({value}:{value:string}){return <div className="qr-box"><QRCodeSVG value={value} size={190} level="H" includeMargin/></div>}
