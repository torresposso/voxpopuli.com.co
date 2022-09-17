async function fetchAPI(query: string, { variables }: any = {}) {
  console.log('hit fetch', import.meta.env.WP_URL);
  const headers = { 'Content-Type': 'application/json' };

  const res = await fetch(import.meta.env.WP_URL, {
    method: 'POST',
    headers,
    body: JSON.stringify({ query, variables }),
  });

  const json = await res.json();
  if (json.errors) {
    console.log(json.errors);
    throw new Error('Failed to fetch API');
  }

  return json.data;
}

export async function getAllPagesWithSlugs() {
  const data = await fetchAPI(`
    {
      pages(first: 10000) {
        edges {
          node {
            slug
          }
        }
      }
    }
    `);
  return data?.pages;
}

export async function getPageBySlug(slug) {
  const data = await fetchAPI(`
    {
      page(id: "${slug}", idType: URI) {
        title
        content
      }
    }
    `);
  return data?.page;
}

export const getStickyPosts = async () => {
  const data = await fetchAPI(`
    {
      posts( where: {onlySticky: true } first:4) {
        nodes {
          id
          title
          date
          categories {
            nodes {
              name
            }
          }
          uri
          featuredImage {
            node {
              sourceUrl
              srcSet
            }
          }
        }
      }
  }
`);

  return data?.posts?.nodes;
};

export async function getPrimaryMenu() {
  const data = await fetchAPI(`
  {
    menu(id:"principal", idType:SLUG) {
      menuItems {
        nodes {
          label
          uri
        }
      }
    }
  }
  `);
  return data?.menu?.menuItems?.nodes;
}
