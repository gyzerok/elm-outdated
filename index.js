const fs = require('fs');
const axios = require('axios');
const table = require('text-table');
const Elm = require('./elm.js');

const elmPackageJson = fs.readFileSync('elm-package.json', { encoding: 'utf-8' });

axios.get("http://package.elm-lang.org/all-packages")
  .then(res => {
    const app = Elm.Main.worker({
      elmPackageJson: JSON.parse(elmPackageJson),
      registry: res.data,
    });

    app.ports.sendReports.subscribe(reports => {
      console.log(
        table(
          [
            ['package', 'current', 'wanted', 'latest'],
            ...reports.map(([name, { current, wanted, latest }]) =>
              [name, current, wanted, latest]
            )
          ],
          { align: ['l', 'r', 'r', 'r'] }
        )
      )
    });
  })
  .catch(err => console.error(err));



