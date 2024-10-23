import React from 'react'
import { DocsThemeConfig } from 'nextra-theme-docs'
import Image from 'next/image'

const config: DocsThemeConfig = {
    logo: (
        <div style={{ display: 'flex', alignItems: 'center' }}>
            <Image
                src="/images/gantrisch.svg"
                alt="Nachthimmelmonitoring Gantrisch"
                width={40}
                height={40}
                style={{ marginRight: '10px' }}
            />
            <span>Nachthimmelmonitoring Gantrisch</span>
        </div>
    ),
    project: {
        link: 'https://github.com/NachthimmelMonitoringGantrisch/NachthimmelMonitoringGantrisch.git',
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
        toggleButton: true,
    },
    editLink: {
        component: null
    },
    feedback: {
        content: 'Feedback geben',
        useLink: () => 'https://github.com/NachthimmelMonitoringGantrisch/NachthimmelMonitoringGantrisch/issues'
    },
}

export default config
