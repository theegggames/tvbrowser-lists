// Blocking-engine regression test. Put in tvshields/src/bin/check.rs and run:
//   cargo run --release --bin check -- path/to/shields.dat
// Exits non-zero if an ad URL is not blocked or a normal site URL is blocked.
use adblock::request::Request;
use adblock::Engine;

fn main() {
    let path = std::env::args().nth(1).expect("usage: check <shields.dat>");
    let data = std::fs::read(&path).expect("cannot read shields.dat");
    let mut e = Engine::default();
    e.deserialize(&data).expect("cannot load shields.dat");

    // (url, page, request type, must be blocked?)
    let cases = [
        ("https://ads.exoclick.com/ad.js", "https://site.com/", "script", true),
        ("https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js", "https://site.com/", "script", true),
        ("https://www.google-analytics.com/analytics.js", "https://site.com/", "script", true),
        ("https://static.doubleclick.net/instream/ad_status.js", "https://site.com/", "script", true),
        ("https://site.com/app.js", "https://site.com/", "script", false),
        ("https://site.com/style.css", "https://site.com/", "stylesheet", false),
        ("https://www.youtube.com/watch?v=abc", "https://www.youtube.com/", "document", false),
        ("https://i.ytimg.com/vi/abc/hqdefault.jpg", "https://www.youtube.com/", "image", false),
        ("https://cdn.jsdelivr.net/npm/hls.js@1/dist/hls.min.js", "https://site.com/", "script", false),
        ("https://www.netflix.com/browse", "https://www.netflix.com/", "document", false),
    ];
    let mut bad = 0;
    for (url, page, ty, want) in cases {
        let r = Request::new(url, page, ty, "GET").unwrap();
        let res = e.check_network_request(&r);
        let blocked = (res.filter.is_some() && res.exception.is_none()) || res.redirect.is_some();
        let ok = blocked == want;
        println!("{} {:<8} {}", if ok { "ok  " } else { "FAIL" }, if want { "block" } else { "allow" }, url);
        if !ok { bad += 1; }
    }
    // speed guard: a lookup must stay fast enough for page loads with hundreds of requests
    let r = Request::new("https://x.com/a.js", "https://y.com/", "script", "GET").unwrap();
    let t = std::time::Instant::now();
    for _ in 0..20000 { std::hint::black_box(e.check_network_request(&r)); }
    let per = t.elapsed().as_micros() as f64 / 20000.0;
    println!("{} 20000 lookups, {:.1} us each (limit 200 us)", if per < 200.0 { "ok  " } else { "FAIL" }, per);
    if per >= 200.0 { bad += 1; }
    println!("{}", if bad == 0 { "ALL ENGINE CHECKS PASSED" } else { "ENGINE CHECKS FAILED" });
    std::process::exit(bad);
}
