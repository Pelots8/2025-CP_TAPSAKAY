import React from 'react'

export default function MapPlaceholder() {
  return (
    <div className="map-placeholder card" aria-hidden="true" style={{position:'relative'}}>
      <img
        src="/map-placeholder.png"
        alt=""
        style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
      />
    </div>
  )
}