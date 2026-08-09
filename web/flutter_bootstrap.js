{{flutter_js}}
{{flutter_build_config}}

// GitHub Pages·모바일: gstatic CDN 대신 번들된 로컬 CanvasKit/skwasm 사용
_flutter.loader.load({
  config: {
    useLocalCanvasKit: true,
  },
});
