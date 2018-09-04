const fs = require("fs");
const https = require("https");
const http = require("http");
const table = require("text-table");
const clc = require("cli-color");

const Main = require("./elm.js").Elm.Main;
const Old = require("./old.js").Elm.Old;

let elmJson;
let elmPackageJson;

try {
  elmJson = fs.readFileSync("elm.json", { encoding: "utf-8" });
} catch (e) {
  try {
    elmPackageJson = fs.readFileSync("elm-package.json", { encoding: "utf-8" });
  } catch (e) {}
}

if (!elmJson && !elmPackageJson) {
  console.error(
    "You should run elm-outdated in the directory where your elm.json is located."
  );
  console.error(
    "If you are using Elm 0.18 then it should be directory with elm-package.json."
  );
  process.exit(1);
} else if (elmJson) {
  fetch("https://package.elm-lang.org/all-packages?elm-package-version=0.19")
    .then(data => {
      let parsedJson;

      try {
        parsedJson = JSON.parse(elmJson);
      } catch (e) {
        console.log("Cannot parse you elm.json. Is it corrupted?");
        process.exit(1);
      }

      const app = Main.init({
        flags: {
          elmJson: parsedJson,
          registry: data
        }
      });

      setup(app);
    })
    .catch(err => console.error(err));
} else if (elmPackageJson) {
  fetch("http://package.elm-lang.org/all-packages?elm-package-version=0.18")
    .then(data => {
      let parsedJson;

      try {
        parsedJson = JSON.parse(elmPackageJson);
      } catch (e) {
        console.log("Cannot parse you elm-package.json. Is it corrupted?");
        process.exit(1);
      }

      const app = Old.init({
        flags: {
          elmPackageJson: parsedJson,
          registry: data
        }
      });

      setup(app);
    })
    .catch(err => console.error(err));
} else {
  console.error("Something wrong happened, please report.");
  process.exit(1);
}

function fetch(url) {
  return new Promise((resolve, reject) => {
    get = url.indexOf("https:") === 0 ? https.get : http.get;
    get(url, res => {
      res.setEncoding("utf8");
      let body = "";
      res.on("data", data => {
        body += data;
      });
      res.on("end", () => {
        try {
          resolve(JSON.parse(body));
        } catch (e) {
          reject(e);
        }
      });
      res.on("error", reject);
    });
  });
}

function setup(app) {
  app.ports.sendError.subscribe(error => {
    console.log(error);
    process.exit(1);
  });

  app.ports.sendReports.subscribe(reports => {
    if (reports.length === 0) {
      console.log("Everything is up to date!");
    } else {
      console.log(
        table(
          [
            ["Package", "Current", "Wanted", "Latest"].map(h =>
              clc.underline(h)
            ),
            ...reports.map(([name, report]) => {
              return !report
                ? [name, "custom", "custom", "custom"]
                : [
                    name,
                    report.current,
                    clc.green(report.wanted),
                    clc.magenta(report.latest)
                  ];
            })
          ],
          {
            align: ["l", "r", "r", "r"],
            stringLength: clc.getStrippedLength
          }
        )
      );
    }
  });
}
