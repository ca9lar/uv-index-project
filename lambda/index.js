const https = require('https');
const AWS = require('aws-sdk');
const sns = new AWS.SNS();

const apiKey = process.env.API_KEY;
const snsTopicArn = process.env.SNS_TOPIC_ARN;
const zipCode = '85226'; // Chandler, AZ ZIP code

exports.handler = async (event) => {
  console.log("Event: ", JSON.stringify(event));

  const coordinates = await getCoordinates(zipCode);
  const uvIndex = await getUVIndex(coordinates.lat, coordinates.lon);

  let message = '';
  if (uvIndex >= 8) {
    message = 'High UV index! Be careful.';
  } else if (uvIndex >= 3) {
    message = 'Moderate UV index.';
  } else {
    message = 'Low UV index.';
  }

  const params = {
    Message: message,
    TopicArn: snsTopicArn
  };

  await sns.publish(params).promise();

  return {
    statusCode: 200,
    body: JSON.stringify({ message: 'UV index alert sent!' }),
  };
};

function getCoordinates(zip) {
  return new Promise((resolve, reject) => {
    const url = `https://api.openweathermap.org/geo/1.0/zip?zip=${zip},US&appid=${apiKey}`;

    https.get(url, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        const geoData = JSON.parse(data);
        resolve({ lat: geoData.lat, lon: geoData.lon });
      });
    }).on('error', (e) => {
      reject(e);
    });
  });
}

function getUVIndex(lat, lon) {
  return new Promise((resolve, reject) => {
    const url = `https://api.openweathermap.org/data/2.5/uvi?appid=${apiKey}&lat=${lat}&lon=${lon}`;

    https.get(url, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        const uvData = JSON.parse(data);
        resolve(uvData.value);
      });
    }).on('error', (e) => {
      reject(e);
    });
  });
}
