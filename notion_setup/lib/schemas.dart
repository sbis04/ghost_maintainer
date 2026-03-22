/// Notion database property schemas and seed content for Ghost Maintainer.

final maintenanceBacklogProps = <String, dynamic>{
  'Title': {'title': {}},
  'Stage': {
    'select': {
      'options': [
        {'name': 'New', 'color': 'gray'},
        {'name': 'Triaged', 'color': 'blue'},
        {'name': 'Investigating', 'color': 'yellow'},
        {'name': 'Review', 'color': 'orange'},
        {'name': 'Deploy', 'color': 'green'},
        {'name': 'Archived', 'color': 'default'},
      ]
    }
  },
  'Priority': {
    'select': {
      'options': [
        {'name': 'P0-Critical', 'color': 'red'},
        {'name': 'P1-High', 'color': 'orange'},
        {'name': 'P2-Medium', 'color': 'yellow'},
        {'name': 'P3-Low', 'color': 'gray'},
      ]
    }
  },
  'Labels': {
    'multi_select': {
      'options': [
        {'name': 'Bug', 'color': 'red'},
        {'name': 'Feature', 'color': 'blue'},
        {'name': 'Docs', 'color': 'green'},
        {'name': 'Performance', 'color': 'yellow'},
        {'name': 'Security', 'color': 'pink'},
        {'name': 'Chore', 'color': 'gray'},
      ]
    }
  },
  'GitHub Issue': {'url': {}},
  'Issue Number': {'number': {'format': 'number'}},
  'PR URL': {'url': {}},
  'AI Summary': {'rich_text': {}},
  'AI Confidence': {'number': {'format': 'number'}},
};

final triageQueueProps = <String, dynamic>{
  'Title': {'title': {}},
  'Stage': {
    'select': {
      'options': [
        {'name': 'New', 'color': 'gray'},
        {'name': 'Triaged', 'color': 'blue'},
        {'name': 'Needs Review', 'color': 'orange'},
        {'name': 'Routed', 'color': 'green'},
      ]
    }
  },
  'Issue Type': {
    'select': {
      'options': [
        {'name': 'Bug', 'color': 'red'},
        {'name': 'Feature', 'color': 'blue'},
        {'name': 'Unknown', 'color': 'gray'},
      ]
    }
  },
  'Priority': {
    'select': {
      'options': [
        {'name': 'P0-Critical', 'color': 'red'},
        {'name': 'P1-High', 'color': 'orange'},
        {'name': 'P2-Medium', 'color': 'yellow'},
        {'name': 'P3-Low', 'color': 'gray'},
      ]
    }
  },
  'Labels': {
    'multi_select': {
      'options': [
        {'name': 'Bug', 'color': 'red'},
        {'name': 'Feature', 'color': 'blue'},
        {'name': 'Docs', 'color': 'green'},
        {'name': 'Performance', 'color': 'yellow'},
        {'name': 'Security', 'color': 'pink'},
        {'name': 'Chore', 'color': 'gray'},
      ]
    }
  },
  'GitHub Issue': {'url': {}},
  'Issue Number': {'number': {'format': 'number'}},
  'AI Summary': {'rich_text': {}},
  'AI Confidence': {'number': {'format': 'number'}},
};

final featureBacklogProps = <String, dynamic>{
  'Title': {'title': {}},
  'Stage': {
    'select': {
      'options': [
        {'name': 'New', 'color': 'gray'},
        {'name': 'Planned', 'color': 'blue'},
        {'name': 'Investigating', 'color': 'yellow'},
        {'name': 'Review', 'color': 'orange'},
        {'name': 'Deploy', 'color': 'green'},
        {'name': 'In Progress', 'color': 'purple'},
        {'name': 'Done', 'color': 'default'},
        {'name': 'Archived', 'color': 'default'},
      ]
    }
  },
  'Priority': {
    'select': {
      'options': [
        {'name': 'P0-Critical', 'color': 'red'},
        {'name': 'P1-High', 'color': 'orange'},
        {'name': 'P2-Medium', 'color': 'yellow'},
        {'name': 'P3-Low', 'color': 'gray'},
      ]
    }
  },
  'Labels': {
    'multi_select': {
      'options': [
        {'name': 'Feature', 'color': 'blue'},
        {'name': 'Enhancement', 'color': 'purple'},
        {'name': 'Docs', 'color': 'green'},
        {'name': 'Performance', 'color': 'yellow'},
      ]
    }
  },
  'GitHub Issue': {'url': {}},
  'Issue Number': {'number': {'format': 'number'}},
  'AI Summary': {'rich_text': {}},
  'AI Confidence': {'number': {'format': 'number'}},
  'PR URL': {'url': {}},
};

final archiveProps = <String, dynamic>{
  'Title': {'title': {}},
  'Type': {
    'select': {
      'options': [
        {'name': 'Bug', 'color': 'red'},
        {'name': 'Feature', 'color': 'blue'},
      ]
    }
  },
  'Priority': {
    'select': {
      'options': [
        {'name': 'P0-Critical', 'color': 'red'},
        {'name': 'P1-High', 'color': 'orange'},
        {'name': 'P2-Medium', 'color': 'yellow'},
        {'name': 'P3-Low', 'color': 'gray'},
      ]
    }
  },
  'Labels': {
    'multi_select': {
      'options': [
        {'name': 'Bug', 'color': 'red'},
        {'name': 'Feature', 'color': 'blue'},
        {'name': 'Docs', 'color': 'green'},
        {'name': 'Performance', 'color': 'yellow'},
        {'name': 'Security', 'color': 'pink'},
        {'name': 'Chore', 'color': 'gray'},
      ]
    }
  },
  'GitHub Issue': {'url': {}},
  'Issue Number': {'number': {'format': 'number'}},
  'PR URL': {'url': {}},
  'AI Summary': {'rich_text': {}},
  'Resolved Date': {'date': {}},
};

final visionContent = <Map<String, dynamic>>[
  {
    'object': 'block',
    'type': 'heading_2',
    'heading_2': {
      'rich_text': [
        {'type': 'text', 'text': {'content': 'Mission'}}
      ]
    },
  },
  {
    'object': 'block',
    'type': 'paragraph',
    'paragraph': {
      'rich_text': [
        {
          'type': 'text',
          'text': {
            'content':
                'Build a reliable, well-documented open-source tool that developers love to use. '
                    'Prioritize stability and developer experience over feature count.'
          }
        }
      ]
    },
  },
  {
    'object': 'block',
    'type': 'heading_2',
    'heading_2': {
      'rich_text': [
        {'type': 'text', 'text': {'content': 'Principles'}}
      ]
    },
  },
  ...[
    'Keep the API surface small and intuitive',
    'Every feature should have comprehensive tests',
    'Performance matters — avoid unnecessary allocations',
    'Security is non-negotiable — validate all inputs',
    'Documentation is a feature, not an afterthought',
  ].map((item) => <String, dynamic>{
        'object': 'block',
        'type': 'bulleted_list_item',
        'bulleted_list_item': {
          'rich_text': [
            {'type': 'text', 'text': {'content': item}}
          ]
        },
      }),
  {
    'object': 'block',
    'type': 'heading_2',
    'heading_2': {
      'rich_text': [
        {'type': 'text', 'text': {'content': 'Current Focus'}}
      ]
    },
  },
  {
    'object': 'block',
    'type': 'paragraph',
    'paragraph': {
      'rich_text': [
        {
          'type': 'text',
          'text': {
            'content':
                'The current release cycle focuses on stability and bug fixes. '
                    'New features are deprioritized until the existing test suite reaches 90% coverage. '
                    'Security issues are always P0.'
          }
        }
      ]
    },
  },
];
