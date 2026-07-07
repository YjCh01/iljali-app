export 'oauth_redirect_stub.dart'
    if (dart.library.html) 'oauth_redirect_web.dart';

import 'oauth_redirect_stub.dart'
    if (dart.library.html) 'oauth_redirect_web.dart' as impl;

void oauthRedirectAssign(String url) => impl.oauthRedirectAssign(url);
