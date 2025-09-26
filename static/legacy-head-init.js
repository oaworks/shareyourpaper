// ----- Legacy head init -----

// API base used by SYP
var api = 'https://beta.oa.works';

window.noddy = window.noddy || {};
if (typeof noddy.loggedin !== 'function') noddy.loggedin = function(){ return false; };
noddy.service = 'openaccessbutton';
noddy.debug = false;
noddy.api = 'https://api.cottagelabs.com';

jQuery(document).ready(function() {

  // Mobile/tablet detection
  window.mobileCheck = function() {
    var check = false;
    (function(a){if(/(android|bb\d+|meego).+mobile|avantgo|bada\/|blackberry|blazer|compal|elaine|fennec|hiptop|iemobile|ip(hone|od)|iris|kindle|lge |maemo|midp|mmp|mobile.+firefox|netfront|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)\/|plucker|pocket|psp|series(4|6)0|symbian|treo|up\.(browser|link)|vodafone|wap|windows ce|xda|xiino|android|ipad|playbook|silk/i.test(a)||/1207|6310|6590|3gso|4thp|50[1-6]i|770s|802s|a wa|abac|ac(er|oo|s\-)|ai(ko|rn)|al(av|ca|co)|amoi|an(ex|ny|yw)|aptu|ar(ch|go)|as(te|us)|attw|au(di|\-m|r |s )|avan|be(ck|ll|nq)|bi(lb|rd)|bl(ac|az)|br(e|v)w|bumb|bw\-(n|u)|c55\/|capi|ccwa|cdm\-|cell|chtm|cldc|cmd\-|co(mp|nd)|craw|da(it|ll|ng)|dbte|dc\-s|devi|dica|dmob|do(c|p)o|ds(12|\-d)|el(49|ai)|em(l2|ul)|er(ic|k0)|esl8|ez([4-7]0|os|wa|ze)|fetc|fly(\-|_)|g1 u|g560|gene|gf\-5|g\-mo|go(\.w|od)|gr(ad|un)|haie|hcit|hd\-(m|p|t)|hei\-|hi(pt|ta)|hp( i|ip)|hs\-c|ht(c(\-| |_|a|g|p|s|t)|tp)|hu(aw|tc)|i\-(20|go|ma)|i230|iac( |\-|\/)|ibro|idea|ig01|ikom|im1k|inno|ipaq|iris|ja(t|v)a|jbro|jemu|jigs|kddi|keji|kgt( |\/)|klon|kpt |kwc\-|kyo(c|k)|le(no|xi)|lg( g|\/(k|l|u)|50|54|\-[a-w])|libw|lynx|m1\-w|m3ga|m50\/|ma(te|ui|xo)|mc(01|21|ca)|m\-cr|me(rc|ri)|mi(o8|oa|ts)|mmef|mo(01|02|bi|de|do|t(\-| |o|v)|zz)|mt(50|p1|v )|mwbp|mywa|n10[0-2]|n20[2-3]|n30(0|2)|n50(0|2|5)|n7(0(0|1)|10)|ne((c|m)\-|on|tf|wf|wg|wt)|nok(6|i)|nzph|o2im|op(ti|wv)|oran|owg1|p800|pan(a|d|t)|pdxg|pg(13|\-([1-8]|c))|phil|pire|pl(ay|uc)|pn\-2|po(ck|rt|se)|prox|psio|pt\-g|qa\-a|qc(07|12|21|32|60|\-[2-7]|i\-)|qtek|r380|r600|raks|rim9|ro(ve|zo)|s55\/|sa(ge|ma|mm|ms|ny|va)|sc(01|h\-|oo|p\-)|sdk\/|se(c(\-|0|1)|47|mc|nd|ri)|sgh\-|shar|sie(\-|m)|sk\-0|sl(45|id)|sm(al|ar|b3|it|t5)|so(ft|ny)|sp(01|h\-|v\-|v )|sy(01|mb)|t2(18|50)|t6(00|10|18)|ta(gt|lk)|tcl\-|tdg\-|tel(i|m)|tim\-|t\-mo|to(pl|sh)|ts(70|m\-|m3|m5)|tx\-9|up(\.b|g1|si)|utst|v400|v750|veri|vi(rg|te)|vk(40|5[0-3]|\-v)|vm40|voda|vulc|vx(52|53|60|61|70|80|81|83|85|98)|w3c(\-| )|webc|whit|wi(g |nc|nw)|wmlb|wonu|x700|yas\-|your|zeto|zte\-/i.test(a.substr(0,4))) check = true;})(navigator.userAgent||navigator.vendor||window.opera);
    return check;
  };

  // Old plugin/install UI logic
  if ($('#getpluginsetc').length && $('#getpluginsetc').is(':visible')) {
    var test = window.location.href.indexOf('dl=') !== -1 ? window.location.href.split('dl=')[1] : undefined;
    if ((test === undefined && mobileCheck()) || test === 'mobile') {
      $('#getpluginsetc').append($('#install_mobile').clone(true).show());
    } else if ((test === undefined && navigator.userAgent.match(/chrome/i) && !navigator.userAgent.match(/edge/i)) || test === 'chrome') {
      $('#getpluginsetc').append($('#install_chrome').clone(true).show());
    } else if ((test === undefined && navigator.userAgent.match(/firefox/i)) || test === 'firefox') {
      $('#getpluginsetc').append($('#install_firefox').clone(true).show());
    } else {
      var target = '#install_bookmarklet_';
      if ((test === undefined && navigator.userAgent.match(/edge/i)) || test === 'edge') target += 'edge';
      else if ((test === undefined && /^((?!chrome|android).)*safari/i.test(navigator.userAgent)) || test === 'safari') target += 'safari';
      else target += 'ie';
      $('#getpluginsetc').append($('#install_bookmarklet').clone(true).show());
      $('.bookmarklet_install_target').attr('data-target',target);
    }
  }

  if (window.location.href.indexOf('odb=true') !== -1) $('#fromopendatabutton').show();
  if (window.location.href.indexOf('team=true') !== -1) $('#fromteambutton').show();

  // Show/hide items based on session
  var logged = noddy.loggedin();
  if (logged) { $('.noddin').show(); $('.nottin').hide(); }

  // Footer spacing tweaks
  $('body').css('min-height',$(window).height()+'px');
  if (window.location.pathname !== '/' && window.location.pathname !== '/request') {
    if (window.location.pathname === '/request') {
      $('#footer').css('margin-top','200px');
    } else if (window.location.pathname.indexOf('/response') !== -1) {
      $('#footer').css({'position':'fixed','bottom':0, 'left': 0, 'right': 0});
    } else if ($('#footer').length && ($('#footer').offset().top + $('#footer').height() < $(window).height())) {
      $('#footer').css('margin-top',$(window).height()-$('#footer').offset().top+'px');
    }
  }

  // Click pings for analytics
  var ping = function() {
    try { $.ajax({ url: noddy.api + '/ping.png?service=openaccessbutton&action=' + $(this).attr('id') }); } catch (err) {}
  };
  $('body').on('click','.pinger',ping);
});

// --- Autorun from DOI-style path (/10....) ---
(function () {
  // Only act on paths like /10.XXXX/...
  var m = location.pathname.replace(/\/+$/,'').match(/^\/(10\.[^\/]+\/.+)$/);
  if (!m) return;
  var doi = m[1];

  function kickOff() {
    var input = document.querySelector('#_oaw_input, #oabutton_input');
    var btn   = document.getElementById('_oaw_find') || document.getElementById('oabutton_find');
    if (input && btn) {
      if (!input.value) input.value = doi;
      btn.click();
      return true;
    }
    return false;
  }

  // Try now, then poll briefly until the embed has rendered
  if (!kickOff()) {
    var tries = 0, t = setInterval(function () {
      if (kickOff() || ++tries > 100) clearInterval(t);
    }, 60);
    window.addEventListener('load', kickOff, { once: true });
  }
})();
