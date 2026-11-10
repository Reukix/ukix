// 2026-07-11 20:21:39
(self.webpackChunk_N_E = self.webpackChunk_N_E || []).push([
  [9410],
  {
    82115: function (e, n, t) {
      "use strict";
      t.d(n, {
        F: function () {
          return c;
        },
      });
      t(80545);

      var r = t(3643),
        o = t.n(r),
        c = {
          success: function (e, n, t) {
            o().info(e || "\u64cd\u4f5c\u6210\u529f", n || 2, t);
          },
          fail: function (e) {
            o().info(e || "\u64cd\u4f5c\u6210\u529f");
          },
        };
    },

    75637: function (e, n, t) {
      "use strict";
      t.d(n, {
        d: function () {
          return b;
        },
      });

      var r = t(14795),
        o = t(18042),
        c = t(26508),
        a = t(41115),
        i = t.n(a),
        u = t(45948),
        s = t(77678),
        l = t(31182),
        d = (function () {
          var e = (0, o.Z)(
            i().mark(function e(n) {
              var t;
              return i().wrap(function (e) {
                for (;;) {
                  switch ((e.prev = e.next)) {
                    case 0:
                      if (((t = n.number), !l.IP.isHarmonyNativePlatform)) {
                        e.next = 5;
                        break;
                      }
                      return e.abrupt("return", (0, s.Q6)("JSPhone", "call", { number: t }));

                    case 5:
                      return e.abrupt("return", Promise.reject());

                    case 6:
                    case "end":
                      return e.stop();
                  }
                }
              }, e);
            })
          );

          return function (n) {
            return e.apply(this, arguments);
          };
        })(),
        p = t(80469),
        f = t(63992),
        _ = ["number", "children", "onClick", "onRiskCheck"];

      function v(e, n) {
        var t = Object.keys(e);
        if (Object.getOwnPropertySymbols) {
          var o = Object.getOwnPropertySymbols(e);
          n &&
            (o = o.filter(function (n) {
              return Object.getOwnPropertyDescriptor(e, n).enumerable;
            })),
            t.push.apply(t, o);
        }
        return t;
      }

      function g(e) {
        for (var n = 1; n < arguments.length; n++) {
          var t = null != arguments[n] ? arguments[n] : {};
          n % 2
            ? v(Object(t), true).forEach(function (n) {
                (0, r.Z)(e, n, t[n]);
              })
            : Object.getOwnPropertyDescriptors
            ? Object.defineProperties(e, Object.getOwnPropertyDescriptors(t))
            : v(Object(t)).forEach(function (n) {
                Object.defineProperty(e, n, Object.getOwnPropertyDescriptor(t, n));
              });
        }
        return e;
      }

      var b = function (e) {
        var n = e.number,
          t = e.children,
          r = e.onClick,
          a = e.onRiskCheck,
          s = (0, c.Z)(e, _),
          v = (0, u.useCallback)(
            (0, o.Z)(
              i().mark(function e() {
                var t;
                return i().wrap(function (e) {
                  for (;;) {
                    switch ((e.prev = e.next)) {
                      case 0:
                        if (!a) {
                          e.next = 6;
                          break;
                        }
                        return (e.next = 3), a();

                      case 3:
                        if (e.sent) {
                          e.next = 6;
                          break;
                        }
                        return e.abrupt("return", false);

                      case 6:
                        return l.IP.isHarmonyNativePlatform
                          ? d({ number: n })
                          : (((t = document.createElement("a")).href = "tel:".concat(n)), t.click()),
                          r && r(),
                          e.abrupt("return", true);

                      case 9:
                      case "end":
                        return e.stop();
                    }
                  }
                }, e);
              })
            ),
            [n, r, a]
          );

        return (0, f.jsx)(p.S, {
          onAsyncClick: v,
          children: (0, f.jsx)(
            "a",
            g(
              g({}, s),
              {},
              {
                children: t,
              }
            )
          ),
        });
      };
    },

    43435: function (e) {
      e.exports = {
        "goods-list-big-container": "index_goods-list-big-container__05Se6",
      };
    },

    70242: function (e) {
      e.exports = {
        container: "index_container__3ARqx",
        hidden: "index_hidden__kbZnj",
        countdown: "index_countdown__V7fdw",
        "gif-container": "index_gif-container__lZMA8",
        "container-type1": "index_container-type1__lD1cV",
        content: "index_content__58ab9",
        "red-pocket-ic": "index_red-pocket-ic__g52HU",
        "type1-text": "index_type1-text__Mafrp",
        btn: "index_btn__vPONm",
      };
    },
  },
]);