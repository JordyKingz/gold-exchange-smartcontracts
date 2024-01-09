export async function getGoldPrice() {
    return await fetch("https://www.goldapi.io/api/XAU/USD", {
        headers: {
            'method': 'GET',
            'x-access-token': `${process.env.GOLD_API_KEY}`,
            'Content-Type': 'application/json'
        }
    })
      .then(response => response.json())
      .catch(error => console.log('error', error));
}
