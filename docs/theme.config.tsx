import React from 'react'
import { DocsThemeConfig } from 'nextra-theme-docs'
import Image from 'next/image'

const config: DocsThemeConfig = {
    logo: (
        <div style={{ display: 'flex', alignItems: 'center' }}>
            <Image
                src="/images/ballenberg.svg"
                alt="Interaktive Webkarte Ballenberg"
                width={40}
                height={40}
                style={{ marginRight: '10px' }}
            />
            <span>Interaktive Webkarte Ballenberg</span>
        </div>
    ),
    project: {
        link: 'https://github.com/InteraktiveWebkarteBallenberg/InteraktiveWebkarteBallenberg.git',
    },
    docsRepositoryBase: 'https://github.com/shuding/nextra-docs-template',
    footer: {
        text: 'Nextra Docs Template',
    },
    search: {
        placeholder: 'Suche...',
    },
    sidebar: {
        defaultMenuCollapseLevel: 1,
    },
    editLink: {
        component: null
    },
    feedback: {
        content: 'Feedback geben',
        useLink: () => 'https://github.com/InteraktiveWebkarteBallenberg/InteraktiveWebkarteBallenberg/issues'
    }
}

export default config
