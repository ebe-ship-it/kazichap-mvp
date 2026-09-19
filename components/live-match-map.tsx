"use client";
import { useEffect, useState } from 'react';
import { APIProvider, AdvancedMarker, Map, useMap } from '@vis.gl/react-google-maps';
import { MapPin } from 'lucide-react';
type Point={user_id:string;lat:number;lng:number;label:string};
function FitPoints({points}:{points:Point[]}){
 const map=useMap();
 // Reframe when the set of participants changes; allow normal panning between updates.
 const identities=points.map(p=>p.user_id).sort().join(',');
 useEffect(()=>{if(!map||!points.length)return;const bounds=new google.maps.LatLngBounds();points.forEach(p=>bounds.extend({lat:p.lat,lng:p.lng}));if(points.length===1){map.setCenter({lat:points[0].lat,lng:points[0].lng});map.setZoom(15);}else map.fitBounds(bounds,70);},[map,identities]); // points intentionally sampled when membership changes
 return null;
}
export function LiveMatchMap({points}:{points:Point[]}){
 const key=process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY;const [failed,setFailed]=useState(false);
 if(!key||/YOUR_|xxx/.test(key)||failed)return <div className="empty map-fallback"><MapPin size={28}/><h3>Map unavailable</h3><p>Use chat to coordinate your meeting point. The rest of your match remains available.</p></div>;
 return <APIProvider apiKey={key} onError={()=>setFailed(true)}><Map className="map-box" defaultCenter={{lat:-6.7924,lng:39.2083}} defaultZoom={13} mapId={process.env.NEXT_PUBLIC_GOOGLE_MAP_ID||'DEMO_MAP_ID'} gestureHandling="cooperative"><FitPoints points={points}/>{points.map(p=><AdvancedMarker key={p.user_id} position={{lat:p.lat,lng:p.lng}} title={p.label}><div className="map-marker"><MapPin size={20}/><span>{p.label}</span></div></AdvancedMarker>)}</Map></APIProvider>;
}
