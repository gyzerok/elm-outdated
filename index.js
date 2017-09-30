const fs = require('fs');
const axios = require('axios');
const table = require('text-table');
const Elm = require('./elm.js');

let elmPackageJson;

try {
  elmPackageJson = fs.readFileSync('elm-package.json', { encoding: 'utf-8' });
}
catch (e) {
  console.error('There is no elm-package.json in the directory your are running elm-outdated from.');
  process.exit(1);
}

axios.get("http://package.elm-lang.org/all-packages")
  .then(res => {
    let parsedJson;

    try {
      parsedJson = JSON.parse(elmPackageJson);
    }
    catch (e) {
      console.log('Your elm-package.json is corrupted.')
      process.exit(1);
    }

    const app = Elm.Main.worker({
      elmPackageJson: parsedJson,
      registry: res.data,
    });

    app.ports.sendError.subscribe(error => {
      console.log(error);
      process.exit(1);
    });

    app.ports.sendReports.subscribe(reports => {
      console.log(
        table(
          [
            ['package', 'current', 'wanted', 'latest'],
            ...reports.map(([name, report]) =>
              !report
                ? [name, 'custom', 'custom', 'custom']
                : [name, report.current, report.wanted, report.latest]
            )
          ],
          { align: ['l', 'r', 'r', 'r'] }
        )
      )
    });
  })
  .catch(err => console.error(err));



